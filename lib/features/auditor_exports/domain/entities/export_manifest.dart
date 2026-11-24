import 'package:equatable/equatable.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';

/// One file listed in the manifest.
final class ManifestFile extends Equatable {
  /// Creates an entry.
  const ManifestFile({
    required this.path,
    required this.sha256,
    required this.sizeBytes,
  });

  /// Path inside the package.
  final String path;

  /// SHA-256 of the file, lowercase hex.
  final String sha256;

  /// Size in bytes.
  final int sizeBytes;

  @override
  List<Object?> get props => [path, sha256, sizeBytes];
}

/// A dataset as exported.
final class ManifestDataset extends Equatable {
  /// Creates an entry.
  const ManifestDataset({
    required this.code,
    required this.files,
    required this.rowCount,
    required this.periodApplied,
  });

  /// Dataset code.
  final String code;

  /// Files that hold it.
  final List<String> files;

  /// Total rows over the files.
  final int rowCount;

  /// Whether the export period filtered it.
  final bool periodApplied;

  @override
  List<Object?> get props => [code, files, rowCount, periodApplied];
}

/// Audit chain state at the moment of export.
final class ManifestAudit extends Equatable {
  /// Creates the summary.
  const ManifestAudit({
    required this.chainStatus,
    required this.eventsChecked,
    this.problem,
    this.checkpointSequence,
    this.checkpointHash,
  });

  /// `intact`, `broken` or `empty`.
  final String chainStatus;

  /// Events examined.
  final int eventsChecked;

  /// First problem found, when broken.
  final String? problem;

  /// Sequence of the last event (a checkpoint to keep elsewhere).
  final int? checkpointSequence;

  /// Hash of the last event.
  final String? checkpointHash;

  @override
  List<Object?> get props => [
    chainStatus,
    eventsChecked,
    problem,
    checkpointSequence,
    checkpointHash,
  ];
}

/// Facts about the application and database at export time.
final class ExportSource extends Equatable {
  /// Creates the facts.
  const ExportSource({
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAtUtc,
  });

  /// Application version.
  final String appVersion;

  /// Database schema version.
  final int schemaVersion;

  /// Export time (UTC).
  final DateTime createdAtUtc;

  @override
  List<Object?> get props => [appVersion, schemaVersion, createdAtUtc];
}

/// The manifest of a complete package: what was exported, from which
/// application and database, with a hash of every file.
///
/// The manifest and `SHA256SUMS` prove the package is *intact*. A checksum
/// does not prove who made it: that needs a signature, which this version
/// does not produce (`signature` is always `null`).
final class ExportManifest extends Equatable {
  /// Creates a manifest.
  const ExportManifest({
    required this.source,
    required this.period,
    required this.format,
    required this.datasets,
    required this.files,
    required this.audit,
    this.notes = const [],
  });

  /// Manifest layout version.
  static const int formatVersion = 1;

  /// Where the data came from.
  final ExportSource source;

  /// The period and how it was chosen.
  final ExportPeriod period;

  /// Delivery format.
  final ExportFormat format;

  /// What was included.
  final List<ManifestDataset> datasets;

  /// Every file with its hash (the manifest and `SHA256SUMS` excluded).
  final List<ManifestFile> files;

  /// Audit chain state.
  final ManifestAudit audit;

  /// Caveats (files that could not be included, amounts convention...).
  final List<String> notes;

  /// JSON map, with keys in a fixed order.
  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'application': 'Inventrix',
    'appVersion': source.appVersion,
    'schemaVersion': source.schemaVersion,
    'createdAtUtc': source.createdAtUtc.toUtc().toIso8601String(),
    'period': {
      'kind': period.kind.code,
      'label': period.label,
      'from': period.fromText,
      'to': period.toText,
    },
    'format': format.code,
    'datasets': [
      for (final d in datasets)
        {
          'code': d.code,
          'files': d.files,
          'rowCount': d.rowCount,
          'periodApplied': d.periodApplied,
        },
    ],
    'files': [
      for (final f in files)
        {'path': f.path, 'sha256': f.sha256, 'sizeBytes': f.sizeBytes},
    ],
    'audit': {
      'chainStatus': audit.chainStatus,
      'eventsChecked': audit.eventsChecked,
      'problem': audit.problem,
      'checkpointSequence': audit.checkpointSequence,
      'checkpointHash': audit.checkpointHash,
    },
    'notes': notes,
    'integrity': {
      'algorithm': 'SHA-256',
      'checksumFile': 'checksums/SHA256SUMS',
      'signature': null,
      'signatureNote':
          'Not signed. The checksums show the files were not changed after '
          'export; they do not prove who created the package.',
    },
  };

  @override
  List<Object?> get props => [source, period, format, datasets, files, audit, notes];
}
