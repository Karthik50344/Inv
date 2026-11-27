import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/database_inspection.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_locations.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_packager.dart';
import 'package:inventrix/features/backup/domain/repositories/database_inspector.dart';
import 'package:inventrix/features/backup/domain/services/restore_compatibility.dart';

/// Validates a backup file **without touching live data**.
///
/// The archive is extracted into a private staging folder (entry names are
/// checked first, links and unknown entries are refused, sizes and SHA-256
/// checksums are verified), the manifest is checked for compatibility, and
/// the database inside is checked with `PRAGMA integrity_check` and
/// `PRAGMA foreign_key_check`.
final class PrepareRestore {
  /// Creates the use case.
  const PrepareRestore({
    required BackupPackager packager,
    required DatabaseInspector inspector,
    required BackupLocations locations,
  }) : _packager = packager,
       _inspector = inspector,
       _locations = locations;

  final BackupPackager _packager;
  final DatabaseInspector _inspector;
  final BackupLocations _locations;

  /// Validates the archive at [archivePath].
  ///
  /// [passphrase] is the recovery passphrase, needed only for a backup made
  /// on another device or installation.
  Future<Result<BackupPreview>> call(
    String archivePath, {
    String? passphrase,
  }) async {
    String? staging;
    var succeeded = false;
    try {
      staging = await _locations.createStagingDirectory();
      final unpacked = await _packager.unpack(
        archivePath: archivePath,
        stagingDirectory: staging,
        passphrase: passphrase,
      );
      if (unpacked case Err<StagedBackup>(:final failure)) {
        return Result.failure(failure);
      }
      final staged = unpacked.valueOrNull!;

      final incompatible = RestoreCompatibility.check(
        staged.manifest,
        appSchemaVersion: _inspector.appSchemaVersion,
      );
      if (incompatible != null) {
        return Result.failure(incompatible);
      }

      final inspected = await _inspector.inspect(
        staged.databasePath,
        key: staged.databaseKey,
      );
      if (inspected case Err<DatabaseInspection>(:final failure)) {
        return Result.failure(failure);
      }
      final inspection = inspected.valueOrNull!;
      if (!inspection.isHealthy) {
        return Result.failure(
          RestoreFailure(
            'This backup is damaged: ${inspection.problem}. Nothing was '
            'changed.',
          ),
        );
      }
      if (inspection.schemaVersion != staged.manifest.schemaVersion) {
        return const Result.failure(
          RestoreFailure(
            'This backup does not match its own description and cannot be '
            'trusted. Nothing was changed.',
          ),
        );
      }
      succeeded = true;
      return Result.success(
        BackupPreview(staged: staged, inspection: inspection),
      );
    } on Object catch (error, stackTrace) {
      return Result.failure(
        RestoreFailure(
          'Could not read this backup. Nothing was changed.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      if (!succeeded && staging != null) {
        await _locations.discard(staging);
      }
    }
  }
}

/// Deletes the staging folder of a backup the user decided not to restore.
final class DiscardStagedBackup {
  /// Creates the use case.
  const DiscardStagedBackup({required BackupLocations locations})
    : _locations = locations;

  final BackupLocations _locations;

  /// Removes [staged] from disk.
  Future<void> call(StagedBackup staged) =>
      _locations.discard(staged.directory);
}
