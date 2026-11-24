import 'package:inventrix/features/auditor_exports/domain/entities/export_manifest.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';

/// Content of the PDF report format.
final class ExportReport {
  /// Creates the report content.
  const ExportReport({
    required this.title,
    required this.manifest,
    required this.highlights,
  });

  /// Title line.
  final String title;

  /// The facts of the export.
  final ExportManifest manifest;

  /// Small tables worth printing in full (tax and HSN/SAC summaries).
  final List<ExportTable> highlights;
}

/// Content of the audit integrity report PDF.
final class IntegrityReport {
  /// Creates the content.
  const IntegrityReport({
    required this.generatedAtUtc,
    required this.audit,
    required this.appVersion,
    required this.schemaVersion,
  });

  /// When the chain was verified.
  final DateTime generatedAtUtc;

  /// Chain state and checkpoint.
  final ManifestAudit audit;

  /// Application version.
  final String appVersion;

  /// Database schema version.
  final int schemaVersion;
}
