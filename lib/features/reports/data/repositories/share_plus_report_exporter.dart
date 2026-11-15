import 'dart:convert';
import 'dart:io';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/reports/domain/repositories/report_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes the CSV to the temporary folder and opens the system share sheet.
final class SharePlusReportExporter implements ReportExporter {
  /// Creates the exporter.
  const SharePlusReportExporter();

  @override
  Future<Result<void>> shareCsv({
    required String fileName,
    required String content,
    required String subject,
  }) async {
    try {
      final folder = await getTemporaryDirectory();
      final file = File(p.join(folder.path, fileName));
      await file.writeAsBytes(utf8.encode(content), flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv')],
          subject: subject,
        ),
      );
      return const Result.success(null);
    } on Object catch (error, stackTrace) {
      return Result.failure(
        UnexpectedFailure(
          'Could not share the report.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
