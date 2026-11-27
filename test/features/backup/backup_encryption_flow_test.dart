import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:inventrix/features/backup/data/services/backup_envelope.dart';
import 'package:inventrix/features/backup/data/services/encrypted_backup_packager.dart';
import 'package:inventrix/features/backup/data/services/file_restore_swapper.dart';
import 'package:inventrix/features/backup/data/services/zip_backup_packager.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_packager.dart';
import 'package:inventrix/features/backup/domain/usecases/create_backup.dart';
import 'package:inventrix/features/backup/domain/usecases/prepare_restore.dart';
import 'package:inventrix/features/backup/domain/usecases/restore_backup.dart';

import '../../support/backup_fakes.dart';

/// A pretend device: its own keys, packager and use cases over shared files.
class _Device {
  _Device(TestStorage storage, this.keys, FakeClock clock) {
    inspector = FakeInspector();
    aligner = FakeAligner();
    packager = EncryptedBackupPackager(
      inner: ZipBackupPackager(),
      keys: keys,
      locations: storage.locations,
      envelope: BackupEnvelope(argonMemoryKib: 64, argonIterations: 1),
    );
    final ids = SeqIds();
    history = InMemoryHistory();
    create = CreateBackup(
      snapshotter: FakeSnapshotter(storage.database),
      inspector: inspector,
      packager: packager,
      locations: storage.locations,
      history: history,
      keys: keys,
      ids: ids,
      clock: clock,
      appVersion: '1.0.0',
    );
    prepare = PrepareRestore(
      packager: packager,
      inspector: inspector,
      locations: storage.locations,
    );
    restore = RestoreBackup(
      inspector: inspector,
      locations: storage.locations,
      createBackup: create,
      keys: keys,
      aligner: aligner,
      swapper: FileRestoreSwapper(),
      journal: InMemoryJournal(),
      runtime: FakeRuntime(),
      ids: ids,
      clock: clock,
    );
  }

  final FakeKeys keys;
  late final FakeInspector inspector;
  late final FakeAligner aligner;
  late final BackupPackager packager;
  late final InMemoryHistory history;
  late final CreateBackup create;
  late final PrepareRestore prepare;
  late final RestoreBackup restore;
}

void main() {
  late TestStorage storage;
  late FakeClock clock;
  late SecretKey256 keyA;
  late SecretKey256 keyB;
  late _Device deviceA;

  setUp(() async {
    storage = await TestStorage.create();
    clock = FakeClock();
    keyA = SecretKey256.generate();
    keyB = SecretKey256.generate();
    deviceA = _Device(storage, FakeKeys(databaseKey: keyA), clock);
    Directory('${storage.docs.path}/attachments').createSync();
    File('${storage.docs.path}/attachments/live.pdf')
        .writeAsStringSync('secret-receipt-content');
  });
  tearDown(() => storage.dispose());

  Future<String> backupOnA({String? passphrase}) async {
    storage.database.writeAsStringSync('customer-ledger-data');
    final record =
        (await deviceA.create(recoveryPassphrase: passphrase)).valueOrNull!;
    return storage.locations.resolveBackup(record.storedPath!);
  }

  test('the backup file is encrypted and leaves no plaintext scratch files', () async {
    final path = await backupOnA();
    final bytes = File(path).readAsBytesSync();
    final text = String.fromCharCodes(bytes);
    expect(text.startsWith('IVXBAK'), isTrue);
    expect(text.startsWith('PK'), isFalse);
    expect(text.contains('customer-ledger-data'), isFalse);
    expect(text.contains('secret-receipt-content'), isFalse);
    expect(text.contains('manifest'), isFalse);
    final leftovers = Directory('${storage.root.path}/tmp')
        .listSync(recursive: true)
        .whereType<File>();
    expect(leftovers, isEmpty);
    expect(deviceA.inspector.inspectedWithKeys.last, keyA);
  });

  test('same device restores without a passphrase and keeps its key', () async {
    final path = await backupOnA();
    storage.database.writeAsStringSync('changed-later');
    final prepared = (await deviceA.prepare(path)).valueOrNull!;
    expect(prepared.staged.databaseKey, keyA);
    expect(prepared.staged.isLegacyPlaintext, isFalse);
    expect(
      (await deviceA.restore(staged: prepared.staged, confirmed: true)).isSuccess,
      isTrue,
    );
    expect(storage.database.readAsStringSync(), 'customer-ledger-data');
    expect(deviceA.aligner.calls.single.$2, keyA);
  });

  test('another device needs the passphrase, then re-keys to its own key', () async {
    final path = await backupOnA(passphrase: 'a long recovery phrase');
    final deviceB = _Device(storage, FakeKeys(databaseKey: keyB), clock);

    final none = await deviceB.prepare(path);
    expect(none.failureOrNull, isA<BackupPassphraseFailure>());
    expect((none.failureOrNull! as BackupPassphraseFailure).incorrect, isFalse);

    final wrong = await deviceB.prepare(path, passphrase: 'not the phrase');
    expect((wrong.failureOrNull! as BackupPassphraseFailure).incorrect, isTrue);
    expect(
      Directory('${storage.docs.path}/restore_staging').existsSync()
          ? Directory('${storage.docs.path}/restore_staging').listSync()
          : <FileSystemEntity>[],
      isEmpty,
    );

    storage.database.writeAsStringSync('changed-later');
    final ok = (await deviceB.prepare(path, passphrase: 'a long recovery phrase'))
        .valueOrNull!;
    expect(ok.staged.databaseKey, keyA); // key of the file inside the backup
    expect(
      (await deviceB.restore(staged: ok.staged, confirmed: true)).isSuccess,
      isTrue,
    );
    // The staged database was converted from the backup's key to B's key.
    expect(deviceB.aligner.calls.single.$1, keyA);
    expect(deviceB.aligner.calls.single.$2, keyB);
    expect(storage.database.readAsStringSync(), 'customer-ledger-data');
  });

  test('without a passphrase slot another device cannot restore', () async {
    final path = await backupOnA();
    final deviceB = _Device(storage, FakeKeys(databaseKey: keyB), clock);
    final result = await deviceB.prepare(path, passphrase: 'anything at all');
    expect(result.failureOrNull, isA<RestoreFailure>());
  });

  test('tampered backup is rejected and nothing is changed', () async {
    final path = await backupOnA();
    final bytes = File(path).readAsBytesSync();
    bytes[bytes.length ~/ 2] ^= 0xff;
    File(path).writeAsBytesSync(bytes);
    storage.database.writeAsStringSync('live-now');
    final result = await deviceA.prepare(path);
    expect(result.failureOrNull, isA<RestoreFailure>());
    expect(storage.database.readAsStringSync(), 'live-now');
  });

  test('truncated backup is rejected', () async {
    final path = await backupOnA();
    final bytes = File(path).readAsBytesSync();
    File(path).writeAsBytesSync(bytes.sublist(0, bytes.length - 40));
    expect((await deviceA.prepare(path)).failureOrNull, isA<RestoreFailure>());
  });

  test('a file that is not a backup is rejected', () async {
    final junk = File('${storage.root.path}/junk.ivxbak')
      ..writeAsStringSync('this is just text');
    expect((await deviceA.prepare(junk.path)).failureOrNull, isA<RestoreFailure>());
  });

  test('legacy unencrypted backups can still be restored and are re-keyed', () async {
    storage.database.writeAsStringSync('legacy-data');
    final legacy = '${storage.root.path}/old.zip';
    final packed = await ZipBackupPackager().pack(
      PackRequest(
        databasePath: storage.database.path,
        dataFolders: const [],
        outputPath: legacy,
        createdAt: clock.now(),
        appVersion: '1.0.0',
        schemaVersion: 9,
      ),
    );
    expect(packed.isSuccess, isTrue);
    storage.database.writeAsStringSync('live-now');
    final prepared = (await deviceA.prepare(legacy)).valueOrNull!;
    expect(prepared.staged.isLegacyPlaintext, isTrue);
    expect(prepared.staged.databaseKey, isNull);
    expect(
      (await deviceA.restore(staged: prepared.staged, confirmed: true)).isSuccess,
      isTrue,
    );
    expect(deviceA.aligner.calls.single.$1, isNull);
    expect(deviceA.aligner.calls.single.$2, keyA);
    expect(storage.database.readAsStringSync(), 'legacy-data');
  });

  test('a failed re-key leaves the live data untouched', () async {
    final path = await backupOnA();
    storage.database.writeAsStringSync('live-now');
    final prepared = (await deviceA.prepare(path)).valueOrNull!;
    deviceA.aligner.failure = const RestoreFailure('cannot rekey');
    final result =
        await deviceA.restore(staged: prepared.staged, confirmed: true);
    expect(result.isSuccess, isFalse);
    expect(storage.database.readAsStringSync(), 'live-now');
  });

  test('a too-short recovery passphrase is refused', () async {
    storage.database.writeAsStringSync('x');
    final result = await deviceA.create(recoveryPassphrase: 'short');
    expect(result.failureOrNull, isA<ValidationFailure>());
  });
}
