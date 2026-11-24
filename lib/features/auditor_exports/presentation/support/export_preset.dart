import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';

/// Starting choices handed to the export wizard (for example from the audit
/// log: "export this period's audit trail").
final class ExportPreset {
  /// Creates a preset.
  const ExportPreset({this.datasets, this.from, this.to, this.format});

  /// Preset for the audit trail of a date range.
  factory ExportPreset.auditTrail({DateTime? from, DateTime? to}) =>
      ExportPreset(
        datasets: const {ExportDataset.auditTrail},
        from: from,
        to: to,
        format: ExportFormat.zip,
      );

  /// Datasets to tick.
  final Set<ExportDataset>? datasets;

  /// Custom range start.
  final DateTime? from;

  /// Custom range end.
  final DateTime? to;

  /// Delivery format.
  final ExportFormat? format;
}
