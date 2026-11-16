import 'package:equatable/equatable.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/backup_format.dart';
import 'package:inventrix/features/backup/domain/entities/backup_manifest.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';

/// Input of [BackupPackager.pack].
final class PackRequest extends Equatable {
  /// Creates a request.
  const PackRequest({
    required this.databasePath,
    required this.dataFolders,
    required this.outputPath,
    required this.createdAt,
    required this.appVersion,
    required this.schemaVersion,
  });

  /// Consistent snapshot to include.
  final String databasePath;

  /// Folders whose files are included (missing folders are skipped).
  final List<BackupDataFolder> dataFolders;

  /// Where the archive is written.
  final String outputPath;

  /// Snapshot time (UTC).
  final DateTime createdAt;

  /// App version for the manifest.
  final String appVersion;

  /// Schema version of [databasePath].
  final int schemaVersion;

  @override
  List<Object?> get props => [
    databasePath,
    dataFolders.map((f) => f.zipName).toList(),
    outputPath,
    createdAt,
    appVersion,
    schemaVersion,
  ];
}

/// A finished archive.
final class PackedBackup extends Equatable {
  /// Creates a packed backup.
  const PackedBackup({
    required this.path,
    required this.sizeBytes,
    required this.sha256,
    required this.manifest,
  });

  /// Archive file.
  final String path;

  /// Archive size.
  final int sizeBytes;

  /// SHA-256 of the archive (lower-case hex).
  final String sha256;

  /// Manifest written into the archive.
  final BackupManifest manifest;

  @override
  List<Object?> get props => [path, sizeBytes, sha256, manifest];
}

/// Reads and writes backup archives (ZIP).
abstract interface class BackupPackager {
  /// Writes the archive described by [request]. The archive appears at
  /// `request.outputPath` only once it is complete.
  Future<Result<PackedBackup>> pack(PackRequest request);

  /// SHA-256 (lower-case hex) of the archive file at [archivePath].
  Future<Result<String>> archiveChecksum(String archivePath);

  /// Re-reads the archive at [archivePath] and checks every checksum without
  /// extracting anything.
  Future<Result<BackupManifest>> verify(String archivePath);

  /// Extracts the archive at [archivePath] into the empty directory
  /// [stagingDirectory] after validating every entry name, rejecting links
  /// and unknown entries, and verifying sizes and SHA-256 checksums. On any
  /// failure nothing remains in [stagingDirectory].
  Future<Result<StagedBackup>> unpack({
    required String archivePath,
    required String stagingDirectory,
  });
}
