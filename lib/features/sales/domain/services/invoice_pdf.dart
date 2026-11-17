import 'dart:typed_data';

import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/sales/domain/services/invoice_layout.dart';

/// Renders an [InvoiceLayout] as a PDF document.
abstract interface class InvoicePdfRenderer {
  /// Returns the bytes of the PDF. [logo] holds the bytes of the business
  /// logo (JPG or PNG); a logo that cannot be decoded is left out.
  Future<Result<Uint8List>> render(InvoiceLayout layout, {Uint8List? logo});
}

/// Hands a generated file to the operating system's share sheet.
abstract interface class InvoiceFileSharer {
  /// Shares [bytes] as a file called [fileName].
  Future<Result<void>> share({
    required Uint8List bytes,
    required String fileName,
    required String subject,
  });
}
