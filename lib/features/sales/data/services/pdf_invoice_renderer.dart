import 'dart:typed_data';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/sales/domain/services/invoice_layout.dart';
import 'package:inventrix/features/sales/domain/services/invoice_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Draws an [InvoiceLayout] with the `pdf` package (A4, built-in fonts).
///
/// It only lays out text the layout already contains, so it holds no
/// business logic. Built-in fonts cover basic Latin only; the layout
/// therefore uses the currency code instead of a symbol. Names in other
/// scripts need an embedded font (a later enhancement).
final class PdfInvoiceRenderer implements InvoicePdfRenderer {
  /// Creates the renderer.
  const PdfInvoiceRenderer();

  @override
  Future<Result<Uint8List>> render(InvoiceLayout layout) async {
    try {
      final document = pw.Document(title: layout.fileName);
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            _header(layout),
            pw.SizedBox(height: 16),
            _meta(layout),
            pw.SizedBox(height: 16),
            _items(layout),
            pw.SizedBox(height: 12),
            _totals(layout),
            if (layout.statusNote != null) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                layout.statusNote!,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red800,
                ),
              ),
            ],
            if (layout.notes != null) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                'Notes',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(layout.notes!),
            ],
          ],
        ),
      );
      return Result.success(await document.save());
    } on Object catch (error, stackTrace) {
      return Result.failure(
        UnexpectedFailure(
          'Could not create the invoice PDF.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  pw.Widget _header(InvoiceLayout layout) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              layout.businessName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            for (final line in layout.businessLines) pw.Text(line),
          ],
        ),
      ),
      pw.Text(
        layout.title,
        style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
      ),
    ],
  );

  pw.Widget _meta(InvoiceLayout layout) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final field in layout.meta)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 90,
                child: pw.Text(
                  field.label,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.Expanded(child: pw.Text(field.value)),
            ],
          ),
        ),
    ],
  );

  pw.Widget _items(InvoiceLayout layout) => pw.TableHelper.fromTextArray(
    headers: layout.columns,
    data: layout.rows,
    headerStyle: pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      fontSize: 9,
    ),
    cellStyle: const pw.TextStyle(fontSize: 9),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
    columnWidths: {
      0: const pw.FixedColumnWidth(22),
      1: const pw.FlexColumnWidth(3),
      2: const pw.FlexColumnWidth(1.4),
      3: const pw.FlexColumnWidth(1.8),
      4: const pw.FlexColumnWidth(1.4),
      5: const pw.FlexColumnWidth(1.8),
      6: const pw.FlexColumnWidth(1.8),
    },
    cellAlignments: {
      0: pw.Alignment.centerLeft,
      1: pw.Alignment.centerLeft,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
      4: pw.Alignment.centerRight,
      5: pw.Alignment.centerRight,
      6: pw.Alignment.centerRight,
    },
  );

  pw.Widget _totals(InvoiceLayout layout) {
    pw.Widget row(String label, String value, {bool strong = false}) {
      final style = pw.TextStyle(
        fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
        fontSize: strong ? 12 : 10,
      );
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: style),
            pw.Text(value, style: style),
          ],
        ),
      );
    }

    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 220,
        child: pw.Column(
          children: [
            for (final t in layout.totals) row(t.label, t.value),
            pw.Divider(),
            row(layout.grandTotal.label, layout.grandTotal.value, strong: true),
          ],
        ),
      ),
    );
  }
}
