import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_history_repository.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_locations.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_packager.dart';

/// Loads the history, newest first. Entries whose internal archive has
/// disappeared (for example deleted through a file manager) lose their
/// stored copy so the screen never offers an action that cannot work.
final class ListBackups {
  /// Creates the use case.
  const ListBackups({
    required BackupHistoryRepository history,
    required BackupLocations locations,
  }) : _history = history,
       _locations = locations;

  final BackupHistoryRepository _history;
  final BackupLocations _locations;

  /// Returns all records.
  Future<Result<List<BackupRecord>>> call() async {
    final loaded = await _history.list();
    if (loaded case Err<List<BackupRecord>>(:final failure)) {
      return Result.failure(failure);
    }
    final records = <BackupRecord>[];
    for (final record in loaded.valueOrNull!) {
      final stored = record.storedPath;
      if (stored != null && !await _locations.backupExists(stored)) {
        await _history.clearStoredPath(record.id);
        records.add(record.copyWith(clearStoredPath: true));
      } else {
        records.add(record);
      }
    }
    return Result.success(records);
  }
}

/// Deletes the app's own copy of a backup (the history row stays).
final class DeleteStoredBackup {
  /// Creates the use case.
  const DeleteStoredBackup({
    required BackupHistoryRepository history,
    required BackupLocations locations,
  }) : _history = history,
       _locations = locations;

  final BackupHistoryRepository _history;
  final BackupLocations _locations;

  /// Deletes the archive of record [id].
  Future<Result<BackupRecord>> call(String id) async {
    final found = await _history.getById(id);
    if (found case Err<BackupRecord>(:final failure)) {
      return Result.failure(failure);
    }
    final record = found.valueOrNull!;
    final stored = record.storedPath;
    if (stored == null) {
      return const Result.failure(
        ValidationFailure('This backup has no stored copy.'),
      );
    }
    try {
      await _locations.deleteBackup(stored);
    } on Object catch (error, stackTrace) {
      return Result.failure(
        BackupFailure(
          'Could not delete the backup file.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
    final cleared = await _history.clearStoredPath(id);
    if (cleared case Err<void>(:final failure)) {
      return Result.failure(failure);
    }
    return Result.success(record.copyWith(clearStoredPath: true));
  }
}

/// Shares a stored backup or saves it to a location the user picks.
///
/// The archive's SHA-256 is compared with the value recorded when it was
/// created, so a file that was modified or damaged in the meantime is never
/// handed out as a good backup.
final class ExportBackup {
  /// Creates the use case.
  const ExportBackup({
    required BackupHistoryRepository history,
    required BackupLocations locations,
    required BackupPackager packager,
    required BackupExporter exporter,
    required Clock clock,
  }) : _history = history,
       _locations = locations,
       _packager = packager,
       _exporter = exporter,
       _clock = clock;

  final BackupHistoryRepository _history;
  final BackupLocations _locations;
  final BackupPackager _packager;
  final BackupExporter _exporter;
  final Clock _clock;

  /// Exports record [id] using [mode]. Resolves to `false` when the user
  /// cancelled.
  Future<Result<bool>> call(String id, ExportMode mode) async {
    final found = await _history.getById(id);
    if (found case Err<BackupRecord>(:final failure)) {
      return Result.failure(failure);
    }
    final record = found.valueOrNull!;
    final stored = record.storedPath;
    if (!record.hasStoredCopy || stored == null) {
      return const Result.failure(
        ValidationFailure('This backup has no stored copy to export.'),
      );
    }
    final String path;
    try {
      path = await _locations.resolveBackup(stored);
      if (!await _locations.backupExists(stored)) {
        return const Result.failure(
          NotFoundFailure('The backup file is no longer on this device.'),
        );
      }
    } on ArgumentError {
      return const Result.failure(
        BackupFailure('The history entry points to an invalid file.'),
      );
    }
    final checksum = await _packager.archiveChecksum(path);
    if (checksum case Err<String>(:final failure)) {
      return Result.failure(failure);
    }
    if (record.sha256 != null && checksum.valueOrNull != record.sha256) {
      return const Result.failure(
        BackupFailure(
          'The stored backup file has changed since it was created, so it '
          'was not exported. Create a new backup instead.',
        ),
      );
    }
    final exported = await _exporter.export(
      path: path,
      fileName: record.fileName,
      mode: mode,
    );
    if (exported case Err<ExportResult>(:final failure)) {
      return Result.failure(failure);
    }
    final outcome = exported.valueOrNull!;
    if (!outcome.completed) {
      return const Result.success(false);
    }
    await _history.markExported(id, _clock.now());
    return const Result.success(true);
  }
}
