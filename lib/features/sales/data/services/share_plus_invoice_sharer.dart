import 'dart:io';
import 'dart:typed_data';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/sales/domain/services/invoice_pdf.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Writes the PDF to the temporary folder and opens the system share sheet.
final class SharePlusInvoiceFileSharer implements InvoiceFileSharer {
  /// Creates the sharer.
  const SharePlusInvoiceFileSharer();

  @override
  Future<Result<void>> share({
    required Uint8List bytes,
    required String fileName,
    required String subject,
  }) async {
    try {
      final folder = await getTemporaryDirectory();
      final file = File(p.join(folder.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          subject: subject,
        ),
      );
      return const Result.success(null);
    } on Object catch (error, stackTrace) {
      return Result.failure(
        UnexpectedFailure(
          'Could not share the invoice.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}
