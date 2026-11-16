import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_history_repository.dart';

/// Drift implementation of [BackupHistoryRepository].
final class DriftBackupHistoryRepository implements BackupHistoryRepository {
  /// Creates the repository.
  const DriftBackupHistoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<void>> add(BackupRecord record) => guardDatabase(
    () => _db
        .into(_db.backupHistory)
        .insert(_toCompanion(record), mode: InsertMode.insertOrIgnore),
  );

  @override
  Future<Result<List<BackupRecord>>> list() => guardDatabase(() async {
    final rows =
        await (_db.select(_db.backupHistory)..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.desc(t.id),
            ]))
            .get();
    return rows.map(_fromRow).toList();
  });

  @override
  Future<Result<BackupRecord>> getById(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.backupHistory,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('Backup not found.'));
    }
    return _fromRow(row);
  });

  @override
  Future<Result<void>> markExported(String id, DateTime at) => guardDatabase(
    () => (_db.update(_db.backupHistory)..where((t) => t.id.equals(id))).write(
      BackupHistoryCompanion(
        exportedAt: Value(at.toUtc().millisecondsSinceEpoch),
      ),
    ),
  );

  @override
  Future<Result<void>> clearStoredPath(String id) => guardDatabase(
    () => (_db.update(_db.backupHistory)..where((t) => t.id.equals(id))).write(
      const BackupHistoryCompanion(storedPath: Value(null)),
    ),
  );

  BackupHistoryCompanion _toCompanion(BackupRecord r) => BackupHistoryCompanion(
    id: Value(r.id),
    kind: Value(r.kind.value),
    fileName: Value(r.fileName),
    storedPath: Value(r.storedPath),
    sizeBytes: Value(r.sizeBytes),
    sha256: Value(r.sha256),
    schemaVersion: Value(r.schemaVersion),
    appVersion: Value(r.appVersion),
    outcome: Value(r.outcome.value),
    errorMessage: Value(r.errorMessage),
    createdAt: Value(r.createdAt.toUtc().millisecondsSinceEpoch),
    exportedAt: Value(r.exportedAt?.toUtc().millisecondsSinceEpoch),
  );

  BackupRecord _fromRow(BackupHistoryRow row) => BackupRecord(
    id: row.id,
    kind: BackupKind.fromValue(row.kind),
    fileName: row.fileName,
    storedPath: row.storedPath,
    sizeBytes: row.sizeBytes,
    sha256: row.sha256,
    schemaVersion: row.schemaVersion,
    appVersion: row.appVersion,
    outcome: BackupOutcome.fromValue(row.outcome),
    errorMessage: row.errorMessage,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
    exportedAt: row.exportedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.exportedAt!, isUtc: true),
  );
}
