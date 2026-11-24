import 'dart:typed_data';

import 'package:inventrix/features/auditor_exports/domain/entities/export_report.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Draws the PDFs of an export with the `pdf` package (A4, built-in fonts,
/// basic Latin only). It lays out text it is given and holds no business
/// logic.
final class PdfExportWriter implements ExportPdfWriter {
  /// Creates the writer.
  const PdfExportWriter();

  static const int _maxHighlightRows = 200;

  @override
  Future<Uint8List> report(ExportReport report) async {
    final m = report.manifest;
    final doc = pw.Document(title: report.title)
      ..addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Text(report.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _facts([
              ['Created (UTC)', m.source.createdAtUtc.toIso8601String()],
              ['Period', m.period.label],
              ['Application version', m.source.appVersion],
              ['Database schema', '${m.source.schemaVersion}'],
              ['Audit trail', _chain(m.audit.chainStatus)],
              if (m.audit.problem != null) ['Audit problem', m.audit.problem!],
              if (m.audit.checkpointHash != null)
                ['Audit checkpoint', '#${m.audit.checkpointSequence} ${m.audit.checkpointHash}'],
              ['Signature', 'Not signed'],
            ]),
            pw.SizedBox(height: 12),
            pw.Text('Included data', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: const ['Dataset', 'Rows', 'Filtered by period'],
              data: [
                for (final d in m.datasets)
                  [d.code, '${d.rowCount}', d.periodApplied ? 'Yes' : 'No (as at export time)'],
              ],
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            for (final table in report.highlights) ...[
              pw.SizedBox(height: 14),
              pw.Text(table.path, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              _table(table),
            ],
            pw.SizedBox(height: 14),
            for (final note in m.notes)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3),
                child: pw.Text('- $note', style: const pw.TextStyle(fontSize: 8)),
              ),
            pw.SizedBox(height: 6),
            pw.Text(
              'This report summarises the export. It does not list every '
              'ledger row: use the CSV, Excel or ZIP export for the full '
              'records.',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      );
    return doc.save();
  }

  @override
  Future<Uint8List> integrity(IntegrityReport report) async {
    final a = report.audit;
    final doc = pw.Document(title: 'Audit integrity report')
      ..addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Text('Audit integrity report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            _facts([
              ['Checked (UTC)', report.generatedAtUtc.toIso8601String()],
              ['Application version', report.appVersion],
              ['Database schema', '${report.schemaVersion}'],
              ['Result', _chain(a.chainStatus)],
              ['Events checked', '${a.eventsChecked}'],
              if (a.problem != null) ['Problem found', a.problem!],
              ['Last event', a.checkpointSequence == null ? 'None' : '#${a.checkpointSequence}'],
              ['Last event hash', a.checkpointHash ?? '-'],
            ]),
            pw.SizedBox(height: 14),
            pw.Text('How to read this', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(
              'Every audit event stores the hash of the event before it and '
              'a hash of its own content. An intact result means no recorded '
              'event was changed, removed or reordered since it was written. '
              'The chain is stored in the same database as the business '
              'data, so someone with direct access to the database file '
              'could rewrite events and their hashes. To detect that, keep '
              'the "last event hash" above somewhere outside the device and '
              'compare it with a later export. Events recorded before the '
              'chain was introduced are in the legacy audit log and are not '
              'covered by it. The actor of an event is a typed local '
              'operator name or this device; it is not verified by '
              'authentication.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
      );
    return doc.save();
  }

  @override
  Future<Uint8List> businessProfile(ExportTable profile) async {
    final rows = <List<String>>[];
    if (profile.rows.isNotEmpty) {
      final row = profile.rows.first;
      for (var i = 0; i < profile.headers.length; i++) {
        if (profile.headers[i] == 'logo_path') {
          continue;
        }
        rows.add([profile.headers[i], '${row[i] ?? ''}']);
      }
    }
    final doc = pw.Document(title: 'Business profile')
      ..addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Business profile', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              rows.isEmpty
                  ? pw.Text('No business profile has been entered.')
                  : _facts(rows),
            ],
          ),
        ),
      );
    return doc.save();
  }

  String _chain(String status) => switch (status) {
    'intact' => 'Intact: no change detected',
    'broken' => 'BROKEN: the audit trail was altered',
    'empty' => 'No audit events recorded yet',
    _ => 'Could not be verified',
  };

  pw.Widget _facts(List<List<String>> rows) => pw.Table(
    columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(5)},
    children: [
      for (final r in rows)
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(r[0], style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(r[1], style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
    ],
  );

  pw.Widget _table(ExportTable table) {
    final shown = table.rows.take(_maxHighlightRows).toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.TableHelper.fromTextArray(
          headers: table.headers,
          data: [
            for (final row in shown) [for (final c in row) c?.toString() ?? ''],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7),
          cellStyle: const pw.TextStyle(fontSize: 7),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        ),
        if (table.rows.length > shown.length)
          pw.Text(
            '... ${table.rows.length - shown.length} more rows in the data files.',
            style: const pw.TextStyle(fontSize: 7),
          ),
      ],
    );
  }
}
