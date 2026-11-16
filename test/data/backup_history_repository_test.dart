import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/features/backup/data/repositories/drift_backup_history_repository.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';

/// Against the real schema (in-memory SQLite). Written without a Flutter SDK:
/// not yet executed.
void main() {
  late AppDatabase db;
  late DriftBackupHistoryRepository repo;

  BackupRecord record(
    String id,
    int minute, {
    BackupKind kind = BackupKind.backup,
  }) => BackupRecord(
    id: id,
    kind: kind,
    fileName: '$id.zip',
    storedPath: '$id.zip',
    sizeBytes: 10,
    sha256: 'a' * 64,
    schemaVersion: 9,
    appVersion: '1.0.0',
    outcome: BackupOutcome.success,
    createdAt: DateTime.utc(2026, 11, 15, 10, minute),
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    repo = DriftBackupHistoryRepository(db);
  });
  tearDown(() => db.close());

  test('adds, lists newest first and round-trips every field', () async {
    await repo.add(record('a', 1));
    await repo.add(record('b', 2, kind: BackupKind.safety));
    final list = (await repo.list()).valueOrNull!;
    expect(list.map((r) => r.id), ['b', 'a']);
    expect(list.last, record('a', 1));
  });

  test(
    'adding the same id twice keeps one row (journal replay is safe)',
    () async {
      await repo.add(record('a', 1));
      expect((await repo.add(record('a', 1))).isSuccess, isTrue);
      expect((await repo.list()).valueOrNull, hasLength(1));
    },
  );

  test('markExported and clearStoredPath update only their column', () async {
    await repo.add(record('a', 1));
    await repo.markExported('a', DateTime.utc(2026, 11, 16));
    await repo.clearStoredPath('a');
    final row = (await repo.getById('a')).valueOrNull!;
    expect(row.exportedAt, DateTime.utc(2026, 11, 16));
    expect(row.storedPath, isNull);
    expect(row.sha256, 'a' * 64);
  });

  test('unknown id is a not-found failure', () async {
    expect((await repo.getById('zzz')).isFailure, isTrue);
  });

  test('CHECK constraints reject unknown kinds and negative sizes', () async {
    Future<void> insert(String kind, int size) => db.customStatement(
      'INSERT INTO backup_history (id, kind, file_name, size_bytes, '
      "schema_version, app_version, outcome, created_at) "
      "VALUES ('x', ?, 'f', ?, 9, '1', 'success', 1)",
      [kind, size],
    );
    await expectLater(insert('weird', 1), throwsA(anything));
    await expectLater(insert('backup', -1), throwsA(anything));
  });

  test('VACUUM INTO produces a healthy standalone copy', () async {
    await repo.add(record('a', 1));
    final dir = await Directory.systemTemp.createTemp('inventrix_snap_');
    addTearDown(() => dir.delete(recursive: true));
    final target = '${dir.path}/snap.sqlite';
    await db.customStatement('VACUUM INTO ?', [target]);
    final copy = AppDatabase(NativeDatabase(File(target)));
    await copy.initialize();
    expect(await copy.integrityCheck(), ['ok']);
    expect(
      (await DriftBackupHistoryRepository(copy).list()).valueOrNull,
      hasLength(1),
    );
    await copy.close();
  });
}
