import 'package:equatable/equatable.dart';
import 'package:inventrix/features/backup/domain/entities/backup_format.dart';

/// A file listed in the manifest together with its checksum.
final class ManifestEntry extends Equatable {
  /// Creates an entry.
  const ManifestEntry({
    required this.path,
    required this.sha256,
    required this.sizeBytes,
  });

  /// Archive path (forward slashes).
  final String path;

  /// SHA-256 of the file content (lower-case hex).
  final String sha256;

  /// Size of the file content in bytes.
  final int sizeBytes;

  @override
  List<Object?> get props => [path, sha256, sizeBytes];
}

/// `manifest.json`: what a backup contains and how to verify it.
final class BackupManifest extends Equatable {
  /// Creates a manifest.
  const BackupManifest({
    required this.formatVersion,
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.entries,
  });

  /// Archive layout version.
  final int formatVersion;

  /// App version that wrote the backup.
  final String appVersion;

  /// Database schema version of the snapshot.
  final int schemaVersion;

  /// When the snapshot was taken (UTC).
  final DateTime createdAt;

  /// Every file except the manifest itself.
  final List<ManifestEntry> entries;

  /// The database entry.
  ManifestEntry get database =>
      entries.firstWhere((entry) => entry.path == BackupFormat.databasePath);

  /// Attachment entries.
  List<ManifestEntry> get attachments => entries
      .where((entry) => entry.path.startsWith(BackupFormat.attachmentsPrefix))
      .toList();

  /// Total declared size of all files.
  int get totalBytes => entries.fold(0, (sum, entry) => sum + entry.sizeBytes);

  @override
  List<Object?> get props => [
    formatVersion,
    appVersion,
    schemaVersion,
    createdAt,
    entries,
  ];
}
