import 'dart:convert';
import 'dart:typed_data';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/audit/domain/usecases/verify_audit_chain.dart';
import 'package:inventrix/features/auditor_exports/data/services/sha256_byte_hasher.dart';
import 'package:inventrix/features/auditor_exports/data/services/xml_xlsx_writer.dart';
import 'package:inventrix/features/auditor_exports/data/services/zip_export_codec.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_report.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/generate_auditor_export.dart';

import '../audit/audit_test_support.dart';

const byteHasher = Sha256ByteHasher();

ExportTable table(String path, List<String> headers, List<List<Object?>> rows) =>
    ExportTable(path: path, headers: headers, rows: rows);

Uint8List bytes(String text) => Uint8List.fromList(utf8.encode(text));

class FakeSnapshot implements ExportSnapshot {
  FakeSnapshot(this.data, {this.attachmentRefs = const [], this.invoiceRefs = const []});
  final Map<ExportDataset, List<ExportTable>> data;
  final List<ExportAttachment> attachmentRefs;
  final List<ExportInvoiceRef> invoiceRefs;
  final List<ExportDataset> reads = [];

  @override
  Future<List<ExportTable>> tables(ExportDataset dataset, ExportPeriod period) async {
    reads.add(dataset);
    return data[dataset] ?? [];
  }

  @override
  Future<int> schemaVersion() async => 13;

  @override
  Future<List<ExportAttachment>> attachments(ExportPeriod period) async => attachmentRefs;

  @override
  Future<List<ExportInvoiceRef>> salesInvoices(ExportPeriod period) async => invoiceRefs;
}

class FakeSource implements ExportDataSource {
  FakeSource(this.snapshot);
  final FakeSnapshot snapshot;
  int snapshots = 0;
  Failure? failure;

  @override
  Future<Result<T>> inSnapshot<T>(Future<T> Function(ExportSnapshot snapshot) action) async {
    snapshots++;
    if (failure != null) {
      return Result.failure(failure!);
    }
    return Result.success(await action(snapshot));
  }
}

class FakeAssets implements ExportAssetReader {
  final Map<String, Uint8List> attachmentFiles = {};

  @override
  Future<Result<Uint8List>> attachment(String storedPath) async {
    final b = attachmentFiles[storedPath];
    return b == null
        ? const Result.failure(ExportFailure('missing'))
        : Result.success(b);
  }

  @override
  Future<Result<Uint8List>> invoicePdf(String invoiceId) async =>
      Result.success(bytes('PDF for $invoiceId'));
}

class FakePdf implements ExportPdfWriter {
  @override
  Future<Uint8List> report(ExportReport report) async => bytes('REPORT ${report.title}');

  @override
  Future<Uint8List> integrity(IntegrityReport report) async =>
      bytes('INTEGRITY ${report.audit.chainStatus}');

  @override
  Future<Uint8List> businessProfile(ExportTable profile) async => bytes('PROFILE');
}

class MemoryStore implements ExportFileStore {
  final Map<String, Uint8List> files = {};
  bool failWrite = false;
  bool corruptOnWrite = false;

  @override
  Future<String> write(String fileName, Uint8List data) async {
    if (failWrite) {
      throw StateError('disk full');
    }
    files[fileName] = corruptOnWrite
        ? Uint8List.fromList([...data, 0])
        : data;
    return '/exports/$fileName';
  }

  @override
  Future<Uint8List?> read(String fileName) async => files[fileName];

  @override
  Future<String> resolve(String fileName) async => '/exports/$fileName';

  @override
  Future<void> delete(String fileName) async => files.remove(fileName);
}

class MemoryHistory implements ExportHistoryRepository {
  final List<ExportRecord> records = [];
  bool failAdd = false;

  @override
  Future<Result<void>> add(ExportRecord record) async {
    if (failAdd) {
      return const Result.failure(DatabaseFailure('history unavailable'));
    }
    records.add(record);
    return const Result.success(null);
  }

  @override
  Future<Result<List<ExportRecord>>> list({int limit = 100}) async =>
      Result.success(records.reversed.take(limit).toList());

  @override
  Future<Result<ExportRecord?>> getById(String id) async {
    for (final r in records) {
      if (r.id == id) {
        return Result.success(r);
      }
    }
    return const Result.success(null);
  }

  @override
  Future<Result<void>> updateIntegrity(String id, {required String status, required DateTime at}) async {
    final i = records.indexWhere((r) => r.id == id);
    final r = records[i];
    records[i] = ExportRecord(
      id: r.id,
      name: r.name,
      createdAt: r.createdAt,
      period: r.period,
      format: r.format,
      datasets: r.datasets,
      fileName: r.fileName,
      sizeBytes: r.sizeBytes,
      sha256: r.sha256,
      integrityStatus: status,
      chainStatus: r.chainStatus,
      appVersion: r.appVersion,
      schemaVersion: r.schemaVersion,
      verifiedAt: at,
      fileDeletedAt: r.fileDeletedAt,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> markFileDeleted(String id, DateTime at) async {
    final i = records.indexWhere((r) => r.id == id);
    final r = records[i];
    records[i] = ExportRecord(
      id: r.id,
      name: r.name,
      createdAt: r.createdAt,
      period: r.period,
      format: r.format,
      datasets: r.datasets,
      fileName: r.fileName,
      sizeBytes: r.sizeBytes,
      sha256: r.sha256,
      integrityStatus: r.integrityStatus,
      chainStatus: r.chainStatus,
      appVersion: r.appVersion,
      schemaVersion: r.schemaVersion,
      verifiedAt: r.verifiedAt,
      fileDeletedAt: at,
    );
    return const Result.success(null);
  }
}

/// Everything the use case needs, wired to in-memory parts.
class ExportHarness {
  ExportHarness({Map<ExportDataset, List<ExportTable>>? data, List<ExportAttachment>? attachments, List<ExportInvoiceRef>? invoices})
    : snapshot = FakeSnapshot(data ?? sampleData(), attachmentRefs: attachments ?? [], invoiceRefs: invoices ?? []) {
    source = FakeSource(snapshot);
    final clock = StepClock(DateTime.utc(2026, 7, 1, 9));
    useCase = GenerateAuditorExport(
      source: source,
      assets: assets,
      hasher: byteHasher,
      xlsx: const XmlXlsxWriter(),
      pdf: FakePdf(),
      zip: const ArchiveExportZipCodec(),
      store: store,
      history: history,
      verifyChain: VerifyAuditChain(repository: audit, hasher: hasher),
      checkpoint: CreateAuditCheckpoint(repository: audit, clock: clock),
      recorder: recorderFor(audit, clock: clock),
      clock: clock,
      ids: CountingIds(),
      appVersion: '1.0.0',
    );
  }

  final FakeSnapshot snapshot;
  late final FakeSource source;
  final FakeAssets assets = FakeAssets();
  final MemoryStore store = MemoryStore();
  final MemoryHistory history = MemoryHistory();
  final MemoryAuditRepository audit = MemoryAuditRepository();
  late final GenerateAuditorExport useCase;
}

Map<ExportDataset, List<ExportTable>> sampleData() => {
  ExportDataset.products: [
    table('master_data/products.csv', ['id', 'sku', 'name'], [
      ['p1', 'A-1', 'Hammer'],
      ['p2', 'B-2', '=HYPERLINK("x")'],
    ]),
  ],
  ExportDataset.salesInvoices: [
    table('sales/sales_invoices.csv', ['id', 'number', 'total_minor'], [
      ['i1', 'INV-1', 11800],
    ]),
    table('sales/sales_invoice_items.csv', ['id', 'invoice_id', 'net_minor'], [
      ['l1', 'i1', 10000],
    ]),
  ],
  ExportDataset.taxSummaries: [
    table('taxation/tax_summaries.csv', ['component', 'tax_minor'], [
      ['CGST', 900],
      ['SGST', 900],
    ]),
  ],
  ExportDataset.businessProfile: [
    table('business_profile/business_profile.csv', ['id', 'name'], [
      ['b1', 'Acme Traders'],
    ]),
  ],
  ExportDataset.auditTrail: [
    table('audit/audit_events.csv', ['seq', 'event_type'], [
      [1, 'audit.chain_started'],
    ]),
  ],
  ExportDataset.stockMovements: [
    table('inventory/stock_movements.csv', ['id', 'quantity_delta_milli'], []),
  ],
};
