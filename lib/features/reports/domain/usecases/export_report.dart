import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/repositories/report_exporter.dart';
import 'package:inventrix/features/reports/domain/services/report_csv.dart';

/// Exports a report as a CSV file through the share sheet.
///
/// The CSV is built from the same [ReportDocument] that is on screen, so
/// the file always matches what the user saw.
final class ExportReportCsv {
  /// Creates the use case.
  const ExportReportCsv({required ReportExporter exporter})
    : _exporter = exporter;

  final ReportExporter _exporter;

  /// Shares [document] as CSV.
  Future<Result<void>> call(ReportDocument document) => _exporter.shareCsv(
    fileName: fileNameFor(document),
    content: ReportCsv.encode(document),
    subject: document.title,
  );

  /// File name such as `inventrix-sales-2026-11-15.csv`.
  static String fileNameFor(ReportDocument document) {
    final d = document.generatedAt.toUtc();
    final date =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    var slug = document.kind;
    for (final kind in ReportKind.values) {
      if (kind.name == document.kind) {
        slug = kind.slug;
      }
    }
    return 'inventrix-$slug-$date.csv';
  }
}
