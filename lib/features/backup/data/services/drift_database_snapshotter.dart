import 'dart:io';

import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/repositories/database_snapshotter.dart';
import 'package:logging/logging.dart';

/// Snapshots the live database with SQLite's `VACUUM INTO`.
///
/// `VACUUM INTO` runs inside a single read transaction, so the copy is
/// consistent even while the app keeps writing, and it works with or without
/// a write-ahead log. Copying the `.sqlite` file directly would not be safe.
final class DriftDatabaseSnapshotter implements DatabaseSnapshotter {
  /// Creates the snapshotter.
  DriftDatabaseSnapshotter(this._db);

  final AppDatabase _db;
  final Logger _log = Logger('DriftDatabaseSnapshotter');

  @override
  Future<Result<void>> snapshotTo(String targetPath) async {
    try {
      if (await File(targetPath).exists()) {
        return const Result.failure(
          BackupFailure('The snapshot file already exists.'),
        );
      }
      await _db.customStatement('VACUUM INTO ?', [targetPath]);
      return const Result.success(null);
    } on Object catch (error, stackTrace) {
      _log.severe('Snapshot failed', error, stackTrace);
      return Result.failure(
        BackupFailure(
          'Could not take a consistent snapshot of the data. Check that '
          'the device has enough free space.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
