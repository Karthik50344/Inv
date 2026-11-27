import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/encrypted_database_opener.dart';
import 'package:inventrix/core/database/sqlcipher_gateway_impl.dart';
import 'package:inventrix/core/security/secret_store.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

class _Store implements SecretStore {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String name) async => values[name];
  @override
  Future<void> write(String name, String value) async => values[name] = value;
}

/// The upgrade path of an existing user: a plaintext Drift database created
/// by the previous version becomes an encrypted one with all data intact.
void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ivx_app_db_');
    path = '${dir.path}/inventory_management.sqlite';
  });
  tearDown(() => dir.delete(recursive: true));

  Future<List<String>> tables(AppDatabase db) async => (await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name",
          )
          .get())
      .map((r) => r.read<String>('name'))
      .toList();

  test('plaintext app database is encrypted without losing anything', () async {
    // 1. What the previous version left on disk.
    final old = AppDatabase(NativeDatabase(File(path)));
    await old.initialize();
    await old.customStatement('CREATE TABLE zz_probe(v TEXT)');
    await old.customStatement("INSERT INTO zz_probe VALUES ('Secret Customer Ltd')");
    final tablesBefore = await tables(old);
    final versionBefore = old.schemaVersion;
    await old.close();
    expect(
      String.fromCharCodes(File(path).readAsBytesSync()).contains('Secret Customer'),
      isTrue,
    );

    // 2. The new version starts.
    final store = _Store();
    final opener = EncryptedDatabaseOpener(
      path: path,
      keys: SecretKeyManager(store),
      gateway: const Sqlite3SqlcipherGateway(),
    );
    final session = await opener.open();
    final hex = session.key.toHex();
    final db = AppDatabase(
      NativeDatabase(File(path), setup: (r) => applyKey(r, hex)),
    );
    await db.initialize();
    await opener.assertEncryptedOnDisk();

    // 3. Nothing lost, nothing re-migrated, nothing readable without the key.
    expect(await tables(db), tablesBefore);
    expect(
      (await db.customSelect('SELECT v FROM zz_probe').getSingle()).read<String>('v'),
      'Secret Customer Ltd',
    );
    expect(
      (await db.customSelect('PRAGMA user_version').getSingle()).read<int>('user_version'),
      versionBefore,
    );
    await db.close();
    expect(
      String.fromCharCodes(File(path).readAsBytesSync()).contains('Secret Customer'),
      isFalse,
    );
    final plain = raw.sqlite3.open(path);
    expect(() => plain.select('SELECT 1 FROM zz_probe'), throwsA(isA<raw.SqliteException>()));
    plain.close();
    expect(dir.listSync().length, 1); // no plaintext leftovers

    // 4. Restart: same key, same data.
    final again = await opener.open();
    expect(again.key, session.key);
  });

  test('a fresh install creates an encrypted database', () async {
    final store = _Store();
    final opener = EncryptedDatabaseOpener(
      path: path,
      keys: SecretKeyManager(store),
      gateway: const Sqlite3SqlcipherGateway(),
    );
    final session = await opener.open();
    final hex = session.key.toHex();
    final db = AppDatabase(
      NativeDatabase(File(path), setup: (r) => applyKey(r, hex)),
    );
    await db.initialize();
    await opener.assertEncryptedOnDisk();
    await db.close();
    expect(
      String.fromCharCodes(File(path).readAsBytesSync(), 0, 15),
      isNot('SQLite format 3'),
    );
  });
}
