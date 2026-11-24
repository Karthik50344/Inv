import 'package:equatable/equatable.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';

/// A finished export, kept in the export history.
final class ExportRecord extends Equatable {
  /// Creates a record.
  const ExportRecord({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.period,
    required this.format,
    required this.datasets,
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
    required this.integrityStatus,
    required this.chainStatus,
    required this.appVersion,
    required this.schemaVersion,
    this.verifiedAt,
    this.fileDeletedAt,
  });

  /// Identifier.
  final String id;

  /// Export name.
  final String name;

  /// When it was created (UTC).
  final DateTime createdAt;

  /// Period covered.
  final ExportPeriod period;

  /// Delivery format.
  final ExportFormat format;

  /// Datasets included.
  final List<ExportDataset> datasets;

  /// File name inside the exports folder.
  final String fileName;

  /// File size in bytes.
  final int sizeBytes;

  /// SHA-256 of the file.
  final String sha256;

  /// `verified`, `failed` or `not_checked`.
  final String integrityStatus;

  /// Audit chain state when exported: `intact`, `broken` or `empty`.
  final String chainStatus;

  /// Application version.
  final String appVersion;

  /// Database schema version.
  final int schemaVersion;

  /// When integrity was last checked.
  final DateTime? verifiedAt;

  /// When the file was removed from the device (the record stays).
  final DateTime? fileDeletedAt;

  /// Whether the file is still on the device.
  bool get hasFile => fileDeletedAt == null;

  @override
  List<Object?> get props => [
    id,
    name,
    createdAt,
    period,
    format,
    datasets,
    fileName,
    sizeBytes,
    sha256,
    integrityStatus,
    chainStatus,
    appVersion,
    schemaVersion,
    verifiedAt,
    fileDeletedAt,
  ];
}
