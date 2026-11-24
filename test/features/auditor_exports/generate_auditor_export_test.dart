import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/auditor_exports/data/services/zip_export_codec.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';
import 'package:inventrix/features/auditor_exports/domain/services/export_verifier.dart';

import '../audit/audit_test_support.dart';
import 'export_test_support.dart';

void main() {
  const zip = ArchiveExportZipCodec();
  const verifier = ExportPackageVerifier(byteHasher);

  ExportRequest request({
    Set<ExportDataset>? datasets,
    ExportFormat format = ExportFormat.zip,
    ExportPeriod? period,
    String? name,
  }) => ExportRequest(
    period: period ?? ExportPeriod.financialYear(2025),
    datasets: datasets ?? {ExportDataset.products, ExportDataset.salesInvoices, ExportDataset.taxSummaries},
    format: format,
    name: name,
  );

  Future<ExportHarness> seeded() async {
    final h = ExportHarness();
    // A real, intact audit chain to export alongside.
    await recorderFor(h.audit).record(draft());
    return h;
  }

  group('complete ZIP package', () {
    test('is written, read back, verified and recorded', () async {
      final h = await seeded();
      final r = await h.useCase(request());
      expect(r.isSuccess, isTrue, reason: r.failureOrNull?.toString());
      final record = r.valueOrNull!;
      expect(record.fileName, endsWith('.zip'));
      expect(record.integrityStatus, 'verified');
      expect(record.format, ExportFormat.zip);
      expect(record.datasets, [ExportDataset.products, ExportDataset.salesInvoices, ExportDataset.taxSummaries]);
      expect(record.sha256, byteHasher.sha256Hex(h.store.files[record.fileName]!));
      expect(record.sizeBytes, h.store.files[record.fileName]!.length);
      expect(h.history.records.single.id, record.id);
    });

    test('the archive on disk is a valid package with the spec layout', () async {
      final h = await seeded();
      final record = (await h.useCase(request())).valueOrNull!;
      final files = zip.decode(h.store.files[record.fileName]!).valueOrNull!;
      expect(verifier.verify(files).isValid, isTrue);
      expect(files.keys, containsAll([
        'Inventrix_Audit_Export/manifest.json',
        'Inventrix_Audit_Export/checksums/SHA256SUMS',
        'Inventrix_Audit_Export/master_data/products.csv',
        'Inventrix_Audit_Export/sales/sales_invoices.csv',
        'Inventrix_Audit_Export/sales/sales_invoice_items.csv',
        'Inventrix_Audit_Export/taxation/tax_summaries.csv',
      ]));
    });

    test('only selected datasets are included and nothing is invented', () async {
      final h = await seeded();
      final record = (await h.useCase(request(datasets: {ExportDataset.products}))).valueOrNull!;
      final files = zip.decode(h.store.files[record.fileName]!).valueOrNull!;
      final csvs = files.keys.where((p) => p.endsWith('.csv')).toList();
      expect(csvs, ['Inventrix_Audit_Export/master_data/products.csv']);
      expect(h.snapshot.reads, [ExportDataset.products]);
    });

    test('every dataset is read inside one consistent snapshot', () async {
      final h = await seeded();
      await h.useCase(request());
      expect(h.source.snapshots, 1);
    });

    test('dangerous text in the data is neutralised in the CSV', () async {
      final h = await seeded();
      final record = (await h.useCase(request(datasets: {ExportDataset.products}))).valueOrNull!;
      final files = zip.decode(h.store.files[record.fileName]!).valueOrNull!;
      final text = utf8.decode(files['Inventrix_Audit_Export/master_data/products.csv']!);
      expect(text, contains("'=HYPERLINK"));
    });

    test('the business profile and integrity PDFs are included when asked', () async {
      final h = await seeded();
      final r = await h.useCase(request(datasets: {ExportDataset.businessProfile, ExportDataset.auditTrail}));
      final files = zip.decode(h.store.files[r.valueOrNull!.fileName]!).valueOrNull!;
      expect(files.keys, containsAll([
        'Inventrix_Audit_Export/business_profile/business_profile.pdf',
        'Inventrix_Audit_Export/audit/audit_integrity_report.pdf',
        'Inventrix_Audit_Export/audit/audit_events.csv',
      ]));
      expect(utf8.decode(files['Inventrix_Audit_Export/audit/audit_integrity_report.pdf']!), 'INTEGRITY intact');
    });

    test('attachments are included, and a missing one is reported, not faked', () async {
      final h = ExportHarness(
        attachments: const [
          ExportAttachment(id: 'a1', ownerType: 'expense', ownerId: 'e1', fileName: 'bill.jpg', storedPath: 'att/a1'),
          ExportAttachment(id: 'a2', ownerType: 'expense', ownerId: 'e1', fileName: 'gone.jpg', storedPath: 'att/a2'),
        ],
      );
      h.assets.attachmentFiles['att/a1'] = bytes('IMG');
      await recorderFor(h.audit).record(draft());
      final r = await h.useCase(request(datasets: {ExportDataset.attachments}));
      final files = zip.decode(h.store.files[r.valueOrNull!.fileName]!).valueOrNull!;
      expect(files.keys, contains('Inventrix_Audit_Export/documents/attachments/expense/e1/a1_bill.jpg'));
      expect(files.keys.any((k) => k.contains('gone.jpg')), isFalse);
      final index = utf8.decode(files['Inventrix_Audit_Export/documents/attachments_index.csv']!);
      expect(index, contains('a2'));
      final manifest = utf8.decode(files['Inventrix_Audit_Export/manifest.json']!);
      expect(manifest, contains('gone.jpg could not be read'));
    });

    test('invoice PDFs are included, one per invoice', () async {
      final h = ExportHarness(invoices: const [
        ExportInvoiceRef(id: 'i1', number: 'INV-1'),
        ExportInvoiceRef(id: 'i2', number: 'INV/2'),
      ]);
      final r = await h.useCase(request(datasets: {ExportDataset.invoicePdfs}));
      final files = zip.decode(h.store.files[r.valueOrNull!.fileName]!).valueOrNull!;
      expect(files.keys, containsAll([
        'Inventrix_Audit_Export/documents/invoice_pdfs/INV-1.pdf',
        'Inventrix_Audit_Export/documents/invoice_pdfs/INV_2.pdf',
      ]));
    });

    test('the manifest states the audit chain and a checkpoint to keep', () async {
      final h = await seeded();
      final r = await h.useCase(request());
      final files = zip.decode(h.store.files[r.valueOrNull!.fileName]!).valueOrNull!;
      final manifest = jsonDecode(utf8.decode(files['Inventrix_Audit_Export/manifest.json']!)) as Map<String, Object?>;
      final auditInfo = manifest['audit']! as Map<String, Object?>;
      expect(auditInfo['chainStatus'], 'intact');
      expect(auditInfo['checkpointSequence'], h.audit.events.last.sequence);
      expect(auditInfo['checkpointHash'], h.audit.events.last.eventHash);
      expect(r.valueOrNull!.chainStatus, 'intact');
    });

    test('a broken audit chain is reported in the export, not hidden', () async {
      final h = await seeded();
      h.audit.events.removeAt(0); // someone deleted the first event
      final r = await h.useCase(request(datasets: {ExportDataset.auditTrail}));
      expect(r.valueOrNull!.chainStatus, 'broken');
      final files = zip.decode(h.store.files[r.valueOrNull!.fileName]!).valueOrNull!;
      expect(utf8.decode(files['Inventrix_Audit_Export/audit/audit_integrity_report.pdf']!), 'INTEGRITY broken');
    });

    test('an export with no audit events yet says so', () async {
      final h = ExportHarness();
      final r = await h.useCase(request());
      expect(r.valueOrNull!.chainStatus, 'empty');
    });
  });

  group('other formats', () {
    test('XLSX is one workbook with a manifest sheet', () async {
      final h = await seeded();
      final r = await h.useCase(request(format: ExportFormat.xlsx));
      expect(r.valueOrNull!.fileName, endsWith('.xlsx'));
      final parts = zip.decode(h.store.files[r.valueOrNull!.fileName]!).valueOrNull!;
      final workbook = utf8.decode(parts['xl/workbook.xml']!);
      expect(workbook, contains('name="manifest"'));
      expect(workbook, contains('name="products"'));
      expect(workbook, contains('name="sales_invoices"'));
    });

    test('PDF is a report', () async {
      final h = await seeded();
      final r = await h.useCase(request(format: ExportFormat.pdf));
      expect(r.valueOrNull!.fileName, endsWith('.pdf'));
      expect(utf8.decode(h.store.files[r.valueOrNull!.fileName]!), startsWith('REPORT '));
    });

    test('CSV of a single table is a plain .csv', () async {
      final h = await seeded();
      final r = await h.useCase(request(datasets: {ExportDataset.products}, format: ExportFormat.csv));
      expect(r.valueOrNull!.fileName, endsWith('.csv'));
      expect(utf8.decode(h.store.files[r.valueOrNull!.fileName]!).replaceFirst('\uFEFF', ''), startsWith('id,sku,name'));
    });

    test('CSV of several tables is a verified zip of CSV files', () async {
      final h = await seeded();
      final r = await h.useCase(request(format: ExportFormat.csv));
      expect(r.valueOrNull!.fileName, endsWith('.zip'));
      final files = zip.decode(h.store.files[r.valueOrNull!.fileName]!).valueOrNull!;
      expect(verifier.verify(files).isValid, isTrue);
      expect(files.keys.where((k) => k.endsWith('.pdf')), isEmpty);
    });
  });

  group('validation and failure handling', () {
    test('nothing selected is refused', () async {
      final r = await ExportHarness().useCase(request(datasets: {}));
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('a start date after the end date is refused', () async {
      final r = await ExportHarness().useCase(
        request(period: ExportPeriod.custom(DateTime.utc(2026, 7), DateTime.utc(2026, 6))),
      );
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('an empty period still produces a valid export', () async {
      final h = ExportHarness(data: {});
      final r = await h.useCase(request());
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull!.integrityStatus, 'verified');
    });

    test('a read failure is returned and no file is left behind', () async {
      final h = ExportHarness();
      h.source.failure = const DatabaseFailure('locked');
      final r = await h.useCase(request());
      expect(r.failureOrNull, isA<DatabaseFailure>());
      expect(h.store.files, isEmpty);
      expect(h.history.records, isEmpty);
    });

    test('if the file cannot be saved the user gets a clear failure', () async {
      final h = ExportHarness();
      h.store.failWrite = true;
      final r = await h.useCase(request());
      expect(r.failureOrNull, isA<ExportFailure>());
      expect(h.history.records, isEmpty);
    });

    test('a file that does not match what was written is discarded', () async {
      final h = ExportHarness();
      h.store.corruptOnWrite = true;
      final r = await h.useCase(request());
      expect(r.failureOrNull, isA<ExportFailure>());
      expect(h.store.files, isEmpty);
      expect(h.history.records, isEmpty);
    });

    test('if the history cannot be saved the file is removed again', () async {
      final h = ExportHarness();
      h.history.failAdd = true;
      final r = await h.useCase(request());
      expect(r.isFailure, isTrue);
      expect(h.store.files, isEmpty);
    });
  });

  group('audit trail of the export itself', () {
    test('an export is recorded as an audit event with its hash', () async {
      final h = await seeded();
      final r = await h.useCase(request(name: 'Year end'));
      final events = h.audit.events.where((e) => e.eventType == 'data_export.created').toList();
      expect(events, hasLength(1));
      final e = events.single;
      expect(e.entityId, r.valueOrNull!.id);
      expect(e.metadata!['name'], 'Year end');
      expect(e.metadata!['sha256'], r.valueOrNull!.sha256);
      expect(e.metadata!['datasets'], ['products', 'sales_invoices', 'tax_summaries']);
      expect(e.actor.type, AuditActorType.localOperator);
    });

    test('if the audit write fails the event is queued, not lost', () async {
      final h = await seeded();
      h.audit.failAppend = true;
      final r = await h.useCase(request());
      expect(r.isSuccess, isTrue);
      expect(h.audit.outbox, hasLength(1));
      expect(h.audit.outbox.single.draft.eventType, 'data_export.created');
    });

    test('the export does not change business data', () async {
      final h = await seeded();
      await h.useCase(request());
      // The fake source exposes only read operations; the snapshot was
      // entered once and nothing else touched the data.
      expect(h.source.snapshots, 1);
    });
  });

  test('a large export completes and verifies', () async {
    final rows = [for (var i = 0; i < 20000; i++) ['id$i', 'INV-$i', i * 100]];
    final h = ExportHarness(
      data: {
        ExportDataset.salesInvoices: [table('sales/sales_invoices.csv', ['id', 'number', 'total_minor'], rows)],
      },
    );
    final r = await h.useCase(request(datasets: {ExportDataset.salesInvoices}));
    expect(r.isSuccess, isTrue, reason: r.failureOrNull?.toString());
    final files = zip.decode(h.store.files[r.valueOrNull!.fileName]!).valueOrNull!;
    expect(verifier.verify(files).isValid, isTrue);
    final csv = utf8.decode(files['Inventrix_Audit_Export/sales/sales_invoices.csv']!);
    expect('\n'.allMatches(csv).length, 20001);
  });
}
