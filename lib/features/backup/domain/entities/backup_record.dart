import 'package:equatable/equatable.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';

/// One row of the backup history.
final class BackupRecord extends Equatable {
  /// Creates a record.
  const BackupRecord({
    required this.id,
    required this.kind,
    required this.fileName,
    required this.sizeBytes,
    required this.schemaVersion,
    required this.appVersion,
    required this.outcome,
    required this.createdAt,
    this.storedPath,
    this.sha256,
    this.errorMessage,
    this.exportedAt,
  });

  /// Unique id.
  final String id;

  /// Kind of entry.
  final BackupKind kind;

  /// Archive file name (or the source name for a restore).
  final String fileName;

  /// Archive location relative to the app's backups folder; `null` when the
  /// internal copy was deleted or the entry has no archive.
  final String? storedPath;

  /// Archive size in bytes.
  final int sizeBytes;

  /// SHA-256 of the archive (lower-case hex).
  final String? sha256;

  /// Database schema version inside the archive.
  final int schemaVersion;

  /// App version that wrote the entry.
  final String appVersion;

  /// Whether the operation succeeded.
  final BackupOutcome outcome;

  /// Reason for a failure (user-safe).
  final String? errorMessage;

  /// When the entry was created (UTC).
  final DateTime createdAt;

  /// When the archive was last shared or saved elsewhere (UTC).
  final DateTime? exportedAt;

  /// Whether an internal archive exists that can be exported or restored.
  bool get hasStoredCopy =>
      outcome == BackupOutcome.success &&
      storedPath != null &&
      kind != BackupKind.restore;

  /// Copy with a new export time and/or a cleared stored copy.
  BackupRecord copyWith({DateTime? exportedAt, bool clearStoredPath = false}) =>
      BackupRecord(
        id: id,
        kind: kind,
        fileName: fileName,
        storedPath: clearStoredPath ? null : storedPath,
        sizeBytes: sizeBytes,
        sha256: sha256,
        schemaVersion: schemaVersion,
        appVersion: appVersion,
        outcome: outcome,
        errorMessage: errorMessage,
        createdAt: createdAt,
        exportedAt: exportedAt ?? this.exportedAt,
      );

  @override
  List<Object?> get props => [
    id,
    kind,
    fileName,
    storedPath,
    sizeBytes,
    sha256,
    schemaVersion,
    appVersion,
    outcome,
    errorMessage,
    createdAt,
    exportedAt,
  ];
}
