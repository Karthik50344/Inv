import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/encrypted_database_opener.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/core/security/secret_store.dart';

const List<int> _magic = [
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, //
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
];

class _Store implements SecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async => values[name] = value;
}

/// Stand-in for SQLCipher: an "encrypted" file starts with `ENC:<hex>:` and
/// is followed by the plaintext bytes. Opens succeed only with that key.
class _FakeGateway implements SqlcipherGateway {
  bool sqlcipher = true;
  Object? failEncrypt;
  int failVerifyAt = -1; // 1-based index of the verify call that fails
  int verifies = 0;
  int encrypts = 0;
  void Function(String target)? afterEncrypt;

  @override
  Future<bool> engineIsSqlcipher() async => sqlcipher;

  @override
  Future<void> verifyUnlocks(String path, SecretKey256 key) async {
    verifies++;
    if (verifies == failVerifyAt) {
      throw const DatabaseSecurityException(
        DatabaseSecurityProblem.unlockFailed,
        'verify failed',
      );
    }
    final bytes = File(path).readAsBytesSync();
    final head = String.fromCharCodes(bytes.take(70));
    if (!head.startsWith('ENC:${key.toHex()}:')) {
      throw const DatabaseSecurityException(
        DatabaseSecurityProblem.unlockFailed,
        'wrong key',
      );
    }
  }

  @override
  Future<void> encryptCopy({
    required String plainPath,
    required String targetPath,
    required SecretKey256 key,
  }) async {
    encrypts++;
    if (failEncrypt != null) {
      throw failEncrypt!;
    }
    File(targetPath).writeAsBytesSync([
      ...'ENC:${key.toHex()}:'.codeUnits,
      ...File(plainPath).readAsBytesSync(),
    ]);
    afterEncrypt?.call(targetPath);
  }
}

void main() {
  late Directory dir;
  late String db;
  late _Store store;
  late _FakeGateway gateway;
  late EncryptedDatabaseOpener opener;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ivx_open_');
    db = '${dir.path}/inventory_management.sqlite';
    store = _Store();
    gateway = _FakeGateway();
    opener = EncryptedDatabaseOpener(
      path: db,
      keys: SecretKeyManager(store),
      gateway: gateway,
    );
  });
  tearDown(() => dir.delete(recursive: true));

  Uint8List plaintextDb(String content) =>
      Uint8List.fromList([..._magic, ...content.codeUnits]);

  List<String> leftovers() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  Future<void> expectProblem(
    Future<Object?> action,
    DatabaseSecurityProblem problem,
  ) => expectLater(
    action,
    throwsA(
      isA<DatabaseSecurityException>().having(
        (e) => e.problem,
        'problem',
        problem,
      ),
    ),
  );

  test('refuses to run when the SQLite library is not SQLCipher', () async {
    gateway.sqlcipher = false;
    await expectProblem(
      opener.open(),
      DatabaseSecurityProblem.engineNotEncrypted,
    );
    expect(store.values, isEmpty);
  });

  test('fresh install creates and stores a key', () async {
    final session = await opener.open();
    expect(session.path, db);
    expect(store.values[SecretNames.databaseKey], session.key.toHex());
    expect(File(db).existsSync(), isFalse); // created by the database layer
  });

  test('plaintext database is encrypted, original wiped, data kept', () async {
    File(db).writeAsBytesSync(plaintextDb('customers-and-invoices'));
    File('$db-wal').writeAsBytesSync([1, 2, 3]);
    final session = await opener.open();
    final bytes = File(db).readAsBytesSync();
    expect(
      String.fromCharCodes(bytes).startsWith('ENC:${session.key.toHex()}:'),
      isTrue,
    );
    expect(String.fromCharCodes(bytes).endsWith('customers-and-invoices'), isTrue);
    expect(await EncryptedDatabaseOpener.formatOf(db), DatabaseFileFormat.opaque);
    expect(leftovers(), ['inventory_management.sqlite']);
  });

  test('second start reuses the stored key without migrating again', () async {
    File(db).writeAsBytesSync(plaintextDb('x'));
    final first = await opener.open();
    final second = await opener.open();
    expect(second.key, first.key);
    expect(gateway.encrypts, 1);
  });

  test('migration failure leaves the plaintext original untouched', () async {
    final original = plaintextDb('precious');
    File(db).writeAsBytesSync(original);
    gateway.failEncrypt = StateError('disk full');
    await expectProblem(opener.open(), DatabaseSecurityProblem.migrationFailed);
    expect(File(db).readAsBytesSync(), original);
    expect(leftovers(), ['inventory_management.sqlite']);
  });

  test('failure while opening the new file puts the original back', () async {
    final original = plaintextDb('precious');
    File(db).writeAsBytesSync(original);
    gateway.failVerifyAt = 2; // tmp verified, live copy fails
    await expectProblem(opener.open(), DatabaseSecurityProblem.unlockFailed);
    expect(File(db).readAsBytesSync(), original);
    expect(leftovers(), ['inventory_management.sqlite']);
  });

  test('encrypted database without its key is never replaced or reset', () async {
    final key = SecretKey256.generate();
    final content = [...'ENC:${key.toHex()}:data'.codeUnits];
    File(db).writeAsBytesSync(content);
    await expectProblem(opener.open(), DatabaseSecurityProblem.keyMissing);
    expect(store.values, isEmpty); // no new key generated
    expect(File(db).readAsBytesSync(), content);
  });

  test('wrong stored key is reported and nothing changes', () async {
    final real = SecretKey256.generate();
    final content = [...'ENC:${real.toHex()}:data'.codeUnits];
    File(db).writeAsBytesSync(content);
    store.values[SecretNames.databaseKey] = SecretKey256.generate().toHex();
    await expectProblem(opener.open(), DatabaseSecurityProblem.unlockFailed);
    expect(File(db).readAsBytesSync(), content);
    expect(store.values.length, 1);
  });

  test('damaged stored key is reported, not replaced', () async {
    File(db).writeAsBytesSync([...'ENC:aa:data'.codeUnits]);
    store.values[SecretNames.databaseKey] = 'garbage';
    await expectProblem(opener.open(), DatabaseSecurityProblem.keyInvalid);
    expect(store.values[SecretNames.databaseKey], 'garbage');
  });

  group('recovery from a crash', () {
    test('after the first rename the original is restored and migrated', () async {
      File('$db.plaintext-old').writeAsBytesSync(plaintextDb('precious'));
      final session = await opener.open();
      expect(
        String.fromCharCodes(File(db).readAsBytesSync()).endsWith('precious'),
        isTrue,
      );
      expect(store.values[SecretNames.databaseKey], session.key.toHex());
      expect(leftovers(), ['inventory_management.sqlite']);
    });

    test('half-written encrypted copy is discarded', () async {
      File(db).writeAsBytesSync(plaintextDb('precious'));
      File('$db.encrypting').writeAsBytesSync([9, 9, 9]);
      await opener.open();
      expect(leftovers(), ['inventory_management.sqlite']);
    });

    test('new file verified: the old plaintext is wiped', () async {
      final key = SecretKey256.generate();
      store.values[SecretNames.databaseKey] = key.toHex();
      File(db).writeAsBytesSync([...'ENC:${key.toHex()}:data'.codeUnits]);
      File('$db.plaintext-old').writeAsBytesSync(plaintextDb('old'));
      await opener.open();
      expect(leftovers(), ['inventory_management.sqlite']);
    });

    test('new file not provable: the plaintext original comes back', () async {
      store.values[SecretNames.databaseKey] = SecretKey256.generate().toHex();
      File(db).writeAsBytesSync([...'ENC:ffff:broken'.codeUnits]);
      final original = plaintextDb('precious');
      File('$db.plaintext-old').writeAsBytesSync(original);
      await opener.open();
      expect(
        String.fromCharCodes(File(db).readAsBytesSync()).endsWith('precious'),
        isTrue,
      );
    });
  });

  test('assertEncryptedOnDisk rejects a plaintext file', () async {
    File(db).writeAsBytesSync(plaintextDb('x'));
    await expectProblem(
      opener.assertEncryptedOnDisk(),
      DatabaseSecurityProblem.engineNotEncrypted,
    );
    File(db).writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
    await opener.assertEncryptedOnDisk();
  });
}
