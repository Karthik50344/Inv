import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';

/// Persistence of the backup history (`backup_history` table).
abstract interface class BackupHistoryRepository {
  /// Adds [record]. Adding an id that already exists is a no-op, so replaying
  /// a restore journal cannot duplicate rows.
  Future<Result<void>> add(BackupRecord record);

  /// All records, newest first.
  Future<Result<List<BackupRecord>>> list();

  /// The record with [id].
  Future<Result<BackupRecord>> getById(String id);

  /// Remembers that the archive of [id] was exported at [at].
  Future<Result<void>> markExported(String id, DateTime at);

  /// Forgets the internal archive of [id] (after the file was deleted).
  Future<Result<void>> clearStoredPath(String id);
}
