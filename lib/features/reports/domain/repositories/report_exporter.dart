import 'package:inventrix/core/result/result.dart';

/// Hands a generated report file to the user (for example through the
/// system share sheet).
abstract interface class ReportExporter {
  /// Shares [content] as a CSV file named [fileName].
  Future<Result<void>> shareCsv({
    required String fileName,
    required String content,
    required String subject,
  });
}
