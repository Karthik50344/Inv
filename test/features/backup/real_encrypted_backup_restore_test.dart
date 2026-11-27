import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/sqlcipher_gateway_impl.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/security/database_key.dart';
import 'package:drift/native.dart';
import 'package:inventrix/features/backup/data/services/app_storage_locations.dart';
import 'package:inventrix/features/backup/data/services/backup_envelope.dart';
import 'package:inventrix/features/backup/data/services/drift_database_snapshotter.dart';
import 'package:inventrix/features/backup/data/services/encrypted_backup_packager.dart';
import 'package:inventrix/features/backup/data/services/file_restore_swapper.dart';
import 'package:inventrix/features/backup/data/services/sqlcipher_key_aligner.dart';
import 'package:inventrix/features/backup/data/services/sqlite_database_inspector.dart';
import 'package:inventrix/features/backup/data/services/zip_backup_packager.dart';
import 'package:inventrix/features/backup/domain/usecases/create_backup.dart';
import 'package:inventrix/features/backup/domain/usecases/prepare_restore.dart';
import 'package:inventrix/features/backup/domain/usecases/restore_backup.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import '../../support/backup_fakes.dart';

/// One pretend phone: its own folders, keys and encrypted Drift database.
class _Phone {
  _Phone(Directory root, this.key) {
    final docs = Directory('${root.path}/docs')..createSync(recursive: true);
    final temp = Directory('${root.path}/tmp')..createSync();
    dbPath = '${docs.path}/inventory_management.sqlite';
    locations = AppStorageLocations(
      documents: () async => docs,
      temporary: () async => temp,
      databasePath: () async => dbPath,
    );
    keys = FakeKeys(databaseKey: key);
    runtime = FakeRuntime()
      ..onShutDown = () async {
        await db.close();
      }
      ..onStart = () async {
        db = open();
        await db.initialize();
      };
  }

  final SecretKey256 key;
  late final String dbPath;
  late final AppStorageLocations locations;
  late final FakeKeys keys;
  late final FakeRuntime runtime;
  late AppDatabase db;

  AppDatabase open() {
    final hex = key.toHex();
    return AppDatabase(
      NativeDatabase(File(dbPath), setup: (r) => applyKey(r, hex)),
    );
  }

  Future<void> start(String ledger) async {
    db = open();
    await db.initialize();
    await db.customStatement('CREATE TABLE IF NOT EXISTS zz_probe(v TEXT)');
    await db.customStatement('DELETE FROM zz_probe');
    await db.customStatement('INSERT INTO zz_probe VALUES (?)', [ledger]);
  }

  Future<String> ledger() async =>
      (await db.customSelect('SELECT v FROM zz_probe').getSingle())
          .read<String>('v');
}

/// The real use cases of [phone] (call after [_Phone.start]).
class _Cases {
  _Cases(_Phone phone, FakeClock clock) {
    final inspector = SqliteDatabaseInspector();
    final packager = EncryptedBackupPackager(
      inner: ZipBackupPackager(),
      keys: phone.keys,
      locations: phone.locations,
      envelope: BackupEnvelope(argonMemoryKib: 64, argonIterations: 1),
    );
    final ids = SeqIds();
    create = CreateBackup(
      snapshotter: DriftDatabaseSnapshotter(phone.db),
      inspector: inspector,
      packager: packager,
      locations: phone.locations,
      history: InMemoryHistory(),
      keys: phone.keys,
      ids: ids,
      clock: clock,
      appVersion: '1.0.0',
    );
    prepare = PrepareRestore(
      packager: packager,
      inspector: inspector,
      locations: phone.locations,
    );
    restore = RestoreBackup(
      inspector: inspector,
      locations: phone.locations,
      createBackup: create,
      keys: phone.keys,
      aligner: SqlcipherKeyAligner(),
      swapper: FileRestoreSwapper(),
      journal: InMemoryJournal(),
      runtime: phone.runtime,
      ids: ids,
      clock: clock,
    );
  }

  late final CreateBackup create;
  late final PrepareRestore prepare;
  late final RestoreBackup restore;
}

void main() {
  late Directory dir;
  late FakeClock clock;
  late SecretKey256 keyA;
  late SecretKey256 keyB;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('ivx_real_');
    clock = FakeClock();
    keyA = SecretKey256.generate();
    keyB = SecretKey256.generate();
  });
  tearDown(() => dir.delete(recursive: true));

  test('backup on phone A restores on phone B under B\'s own key', () async {
    final a = _Phone(Directory('${dir.path}/a'), keyA);
    await a.start('ledger-of-phone-A');
    final casesA = _Cases(a, clock);
    final record =
        (await casesA.create(recoveryPassphrase: 'phone-A recovery phrase'))
            .valueOrNull;
    expect(record != null, isTrue);
    final backupPath = await a.locations.resolveBackup(record!.storedPath!);

    // The backup is neither a ZIP nor SQLite and hides the content.
    final text = String.fromCharCodes(File(backupPath).readAsBytesSync());
    expect(text.startsWith('IVXBAK'), isTrue);
    expect(text.contains('ledger-of-phone-A'), isFalse);
    expect(text.contains('SQLite format 3'), isFalse);
    // Phone A's own database file cannot be read without the key.
    await a.db.close();
    final plain = raw.sqlite3.open(a.dbPath);
    expect(
      () => plain.select('SELECT * FROM zz_probe'),
      throwsA(isA<raw.SqliteException>()),
    );
    plain.close();

    // Phone B: different keys, different data.
    final b = _Phone(Directory('${dir.path}/b'), keyB);
    await b.start('ledger-of-phone-B');
    final casesB = _Cases(b, clock);

    expect(
      (await casesB.prepare(backupPath)).failureOrNull,
      isA<BackupPassphraseFailure>(),
    );
    final wrong = await casesB.prepare(backupPath, passphrase: 'not the phrase');
    expect((wrong.failureOrNull! as BackupPassphraseFailure).incorrect, isTrue);

    final prepared = (await casesB.prepare(
      backupPath,
      passphrase: 'phone-A recovery phrase',
    )).valueOrNull!;
    final outcome = await casesB.restore(staged: prepared.staged, confirmed: true);
    expect(outcome.failureOrNull == null, isTrue);

    // Phone B now serves A's data and opens ONLY with B's key.
    expect(await b.ledger(), 'ledger-of-phone-A');
    await b.db.close();
    expect(() => _unlock(b.dbPath, keyA), throwsA(isA<raw.SqliteException>()));
    final ok = _unlock(b.dbPath, keyB);
    expect(ok.select('SELECT v FROM zz_probe').single['v'], 'ledger-of-phone-A');
    ok.close();
    final head = File(b.dbPath).openSync().readSync(15);
    expect(String.fromCharCodes(head), isNot('SQLite format 3'));
  });
}

raw.Database _unlock(String path, SecretKey256 key) {
  final db = raw.sqlite3.open(path);
  applyKey(db, key.toHex());
  db.select('SELECT count(*) FROM sqlite_master');
  return db;
}
