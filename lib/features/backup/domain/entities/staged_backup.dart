import 'package:equatable/equatable.dart';
import 'package:inventrix/features/backup/domain/entities/backup_manifest.dart';
import 'package:inventrix/features/backup/domain/entities/database_inspection.dart';

/// A backup that has been extracted into a private staging folder and
/// verified (paths, checksums). Nothing here touches live data.
final class StagedBackup extends Equatable {
  /// Creates a staged backup.
  const StagedBackup({
    required this.manifest,
    required this.directory,
    required this.databasePath,
    required this.dataFolders,
    required this.sourceName,
    required this.archiveSha256,
    required this.archiveSizeBytes,
  });

  /// Verified manifest.
  final BackupManifest manifest;

  /// Staging root (deleted when the backup is discarded).
  final String directory;

  /// Extracted database file.
  final String databasePath;

  /// Extracted data folders, by archive name (`receipts`, `product_images`).
  final Map<String, String> dataFolders;

  /// File name the user picked.
  final String sourceName;

  /// SHA-256 of the archive file.
  final String archiveSha256;

  /// Size of the archive file.
  final int archiveSizeBytes;

  @override
  List<Object?> get props => [
    manifest,
    directory,
    databasePath,
    dataFolders,
    sourceName,
    archiveSha256,
    archiveSizeBytes,
  ];
}

/// A staged backup plus what the database inside contains, shown to the
/// user before they confirm a restore.
final class BackupPreview extends Equatable {
  /// Creates a preview.
  const BackupPreview({required this.staged, required this.inspection});

  /// The staged backup.
  final StagedBackup staged;

  /// Health and contents of its database.
  final DatabaseInspection inspection;

  @override
  List<Object?> get props => [staged, inspection];
}
