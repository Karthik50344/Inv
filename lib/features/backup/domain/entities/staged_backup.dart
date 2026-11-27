import 'package:equatable/equatable.dart';
import 'package:inventrix/core/security/database_key.dart';
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
    this.databaseKey,
    this.isLegacyPlaintext = false,
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

  /// Key of the staged database file (kept in memory only). `null` means the
  /// staged database is a plain, unencrypted file from a legacy backup.
  final SecretKey256? databaseKey;

  /// Whether this came from an old, unencrypted backup file.
  final bool isLegacyPlaintext;

  /// Copy with the database key, legacy flag and (optionally) the details of
  /// the outer file set.
  StagedBackup withSecurity({
    SecretKey256? databaseKey,
    bool isLegacyPlaintext = false,
    String? sourceName,
    String? archiveSha256,
    int? archiveSizeBytes,
  }) => StagedBackup(
    manifest: manifest,
    directory: directory,
    databasePath: databasePath,
    dataFolders: dataFolders,
    sourceName: sourceName ?? this.sourceName,
    archiveSha256: archiveSha256 ?? this.archiveSha256,
    archiveSizeBytes: archiveSizeBytes ?? this.archiveSizeBytes,
    databaseKey: databaseKey,
    isLegacyPlaintext: isLegacyPlaintext,
  );

  @override
  List<Object?> get props => [
    manifest,
    directory,
    databasePath,
    dataFolders,
    sourceName,
    archiveSha256,
    archiveSizeBytes,
    databaseKey,
    isLegacyPlaintext,
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
