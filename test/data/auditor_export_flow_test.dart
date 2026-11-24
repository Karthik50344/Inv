import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/features/audit/data/repositories/audit_event_log_repository.dart';
import 'package:inventrix/features/audit/data/repositories/drift_audit_event_repository.dart';
import 'package:inventrix/features/audit/data/services/settings_audit_actor_provider.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';
import 'package:inventrix/features/audit/domain/usecases/verify_audit_chain.dart';
import 'package:inventrix/features/auditor_exports/data/repositories/drift_export_history_repository.dart';
import 'package:inventrix/features/auditor_exports/data/services/drift_export_data_source.dart';
import 'package:inventrix/features/auditor_exports/data/services/xml_xlsx_writer.dart';
import 'package:inventrix/features/auditor_exports/data/services/zip_export_codec.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/services/export_verifier.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/generate_auditor_export.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/sales/data/repositories/drift_sales_repository.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/taxation/data/repositories/drift_tax_repository.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/tax_line_service.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../core/database/database_test_helpers.dart';
import '../features/audit/audit_test_support.dart';
import '../features/auditor_exports/export_test_support.dart';

class _NoSettings implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Money inr(int minor) => Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

/// The spec's integration scenario over the real schema: tax category ->
/// posted invoice with tax snapshot -> tax configuration changes -> audit
/// events -> auditor export -> archive and checksums verified. Written
/// without a Flutter SDK: not yet executed.
void main() {
  late AppDatabase db;
  late DriftSalesRepository sales;
  late TaxLineService taxLines;
  late GenerateAuditorExport export;
  late MemoryStore store;
  late AuditEventLogRepository audit;
  const zip = ArchiveExportZipCodec();

  Future<SalesLine> line(String id) async {
    final taxed = (await taxLines.calculate(
      productTaxCategoryId: 'cat',
      productTaxOverrideId: null,
      type: TaxTransactionType.sale,
      date: DateTime.utc(2026, 6, 1),
      unitPrice: inr(10000),
      quantity: Quantity.fromUnits(2),
      priceIncludesTax: false,
      discount: const Discount.none(),
    )).valueOrNull!;
    return SalesLine(
      id: id,
      lineNo: 1,
      productId: 'p1',
      productName: 'Product p1',
      sku: 'A',
      unitSymbol: 'pcs',
      unitDecimalPlaces: 0,
      quantity: Quantity.fromUnits(2),
      unitPrice: inr(10000),
      priceIncludesTax: false,
      discount: const Discount.none(),
      taxRateBp: taxed.taxRateBp,
      taxName: taxed.taxName,
      amounts: taxed.amounts,
      taxSnapshot: taxed.snapshot,
      classification: const ClassificationSnapshot(system: 'hsn', code: '8471', description: 'Computers'),
    );
  }

  Future<void> postInvoice(String id, String number, DateTime date) async {
    final l = await line('l-$id');
    final invoice = SalesInvoice(
      id: id,
      customerName: 'Walk-in customer',
      status: DocumentStatus.draft,
      invoiceDate: date,
      lines: [l],
      totals: SalesTotals.fromLines([l], zero: inr(0)),
      createdAt: date,
      updatedAt: date,
    );
    expect((await sales.saveDraft(invoice)).isSuccess, isTrue);
    expect((await sales.markPosted(id, number: number, at: date)).isSuccess, isTrue);
    await audit.record(
      AuditEntry(
        id: 'a-$id',
        entityType: 'sales_invoice',
        entityId: id,
        action: 'posted',
        summary: 'Posted $number',
        occurredAt: date,
      ),
    );
  }

  ExportRequest req(ExportPeriod period, {ExportFormat format = ExportFormat.zip, Set<ExportDataset>? datasets}) =>
      ExportRequest(
        period: period,
        datasets: datasets ??
            {
              ExportDataset.businessProfile,
              ExportDataset.products,
              ExportDataset.productClassifications,
              ExportDataset.salesInvoices,
              ExportDataset.inventoryBalances,
              ExportDataset.stockMovements,
              ExportDataset.taxConfigurations,
              ExportDataset.taxSummaries,
              ExportDataset.hsnSummaries,
              ExportDataset.auditTrail,
            },
        format: format,
      );

  Future<Map<String, String>> textFiles(String fileName) async {
    final files = zip.decode(store.files[fileName]!).valueOrNull!;
    expect(const ExportPackageVerifier(byteHasher).verify(files).isValid, isTrue);
    return {for (final e in files.entries) e.key: utf8.decode(e.value, allowMalformed: true)};
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    await insertUnit(db, 'u1');
    await insertProduct(db, 'p1', sku: 'A');
    await db.customStatement(
      "INSERT INTO tax_regimes (id, name, country_code, currency_code, is_active, created_at, updated_at) VALUES ('r', 'Test', 'IN', 'INR', 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tax_categories (id, name, code, default_tax_treatment, is_active, created_at, updated_at) VALUES ('cat', 'Standard', 'STD', 'standard_rated', 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tax_profiles (id, name, regime_id, is_default, default_tax_category_id, is_active, created_at, updated_at) VALUES ('prof', 'Profile', 'r', 1, 'cat', 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tax_rules (id, tax_profile_id, tax_category_id, supply_relation, calculation_method, effective_from, created_at, updated_at) VALUES ('rule', 'prof', 'cat', 'intra', 'percentage', 0, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tax_components (id, tax_rule_id, name, component_type, rate_basis_points, calculation_order, is_compound, is_recoverable, is_active, created_at, updated_at) VALUES ('cg', 'rule', 'CGST', 'cgst', 900, 1, 0, 0, 1, 1, 1), ('sg', 'rule', 'SGST', 'sgst', 900, 2, 0, 0, 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO app_settings (key, value, updated_at) VALUES ('tax_country_code', 'IN', 1), ('tax_region_code', 'KA', 1)",
    );
    await db.customStatement(
      "INSERT INTO product_classifications (id, product_id, classification_system, classification_code, classification_description, classification_type, is_primary, created_at, updated_at) VALUES ('c1', 'p1', 'hsn', '8471', 'Computers', 'goods', 1, 1, 1)",
    );
    await insertMovement(db, 'm1', productId: 'p1', type: 'purchase', deltaMilli: 5000, totalCostMinor: 25000);

    sales = DriftSalesRepository(db, _NoSettings());
    taxLines = TaxLineService(repository: DriftTaxRepository(db));
    final events = DriftAuditEventRepository(db);
    final clock = StepClock(DateTime.utc(2026, 12, 1));
    final recorder = AuditRecorder(
      repository: events,
      actors: SettingsAuditActorProvider(db),
      hasher: hasher,
      clock: clock,
      ids: CountingIds(),
    );
    audit = AuditEventLogRepository(recorder: recorder, events: events, legacy: DriftAuditLogRepository(db));
    store = MemoryStore();
    export = GenerateAuditorExport(
      source: DriftExportDataSource(db),
      assets: FakeAssets(),
      hasher: byteHasher,
      xlsx: const XmlXlsxWriter(),
      pdf: FakePdf(),
      zip: zip,
      store: store,
      history: DriftExportHistoryRepository(db),
      verifyChain: VerifyAuditChain(repository: events, hasher: hasher),
      checkpoint: CreateAuditCheckpoint(repository: events, clock: clock),
      recorder: recorder,
      clock: clock,
      ids: CountingIds(),
      appVersion: '1.0.0',
    );

    // Two posted invoices in different financial years.
    await postInvoice('inv1', 'INV-1', DateTime.utc(2026, 6, 1)); // FY 2026-27
    await postInvoice('inv2', 'INV-2', DateTime.utc(2025, 8, 1)); // FY 2025-26
  });

  tearDown(() => db.close());

  test('the export contains the invoice, tax, classification, inventory and '
      'audit records, and the archive and checksums verify', () async {
    final r = await export(req(ExportPeriod.financialYear(2026)));
    expect(r.isSuccess, isTrue, reason: r.failureOrNull?.toString());
    final files = await textFiles(r.valueOrNull!.fileName);
    const root = 'Inventrix_Audit_Export';

    // Period filter: only the FY 2026-27 invoice.
    final invoices = files['$root/sales/sales_invoices.csv']!;
    expect(invoices, contains('INV-1'));
    expect(invoices, isNot(contains('INV-2')));
    expect(files['$root/sales/sales_invoice_items.csv']!, contains('CGST + SGST'));
    expect(files['$root/sales/sales_invoice_items.csv']!, contains('8471'));

    // Tax summary: components with exact figures (2 x 100.00 at 9% + 9%).
    final tax = files['$root/taxation/tax_summaries.csv']!;
    expect(tax, contains('sales,CGST,cgst,900,1,20000,1800'));
    expect(tax, contains('sales,SGST,sgst,900,1,20000,1800'));
    expect(files['$root/taxation/treatment_summaries.csv']!, contains('sales,standard_rated,1,20000,3600'));
    expect(files['$root/taxation/invoice_tax_components.csv']!, contains('INV-1'));

    // HSN summary.
    expect(files['$root/taxation/hsn_summaries.csv']!, contains('sales,hsn,8471,Computers,pcs,1,2000,20000,3600,23600'));

    // Tax configuration and classifications.
    expect(files['$root/taxation/tax_configurations.csv']!, contains('CGST'));
    expect(files['$root/master_data/product_classifications.csv']!, contains('8471'));

    // Inventory and the audit trail.
    expect(files['$root/inventory/inventory_balances.csv']!, contains('quantity_on_hand_milli'));
    expect(files['$root/inventory/stock_movements.csv']!, contains('quantity_delta_milli'));
    final events = files['$root/audit/audit_events.csv']!;
    expect(events, contains('audit.chain_started'));
    expect(events, contains('sales_invoice.posted'));
    final manifest = jsonDecode(files['$root/manifest.json']!) as Map<String, Object?>;
    expect((manifest['audit']! as Map)['chainStatus'], 'intact');
    expect(manifest['schemaVersion'], AppDatabase.currentSchemaVersion);
  });

  test('all dates also includes the stock movement and its product', () async {
    final r = await export(
      req(const ExportPeriod.all(), datasets: {ExportDataset.stockMovements, ExportDataset.inventoryBalances}),
    );
    final files = await textFiles(r.valueOrNull!.fileName);
    final movements = files['Inventrix_Audit_Export/inventory/stock_movements.csv']!;
    expect(movements, contains('m1'));
    expect(movements, contains('1970-01-01T00:00:00.001Z')); // epoch ms shown as ISO UTC
    expect(files['Inventrix_Audit_Export/inventory/inventory_valuation.csv']!, contains('average_unit_cost_minor'));
  });

  test('all dates includes both invoices', () async {
    final r = await export(req(const ExportPeriod.all(), datasets: {ExportDataset.salesInvoices}));
    final files = await textFiles(r.valueOrNull!.fileName);
    final invoices = files['Inventrix_Audit_Export/sales/sales_invoices.csv']!;
    expect(invoices, allOf(contains('INV-1'), contains('INV-2')));
  });

  test('a custom range includes both ends of the boundary day', () async {
    final r = await export(
      req(
        ExportPeriod.custom(DateTime.utc(2025, 8, 1), DateTime.utc(2025, 8, 1)),
        datasets: {ExportDataset.salesInvoices},
      ),
    );
    final invoices = (await textFiles(r.valueOrNull!.fileName))['Inventrix_Audit_Export/sales/sales_invoices.csv']!;
    expect(invoices, contains('INV-2'));
    expect(invoices, isNot(contains('INV-1')));
  });

  test('an empty period gives header-only CSV files, not missing ones', () async {
    final r = await export(
      req(
        ExportPeriod.custom(DateTime.utc(2030), DateTime.utc(2030, 12, 31)),
        datasets: {ExportDataset.salesInvoices, ExportDataset.taxSummaries, ExportDataset.hsnSummaries},
      ),
    );
    final files = await textFiles(r.valueOrNull!.fileName);
    expect(files['Inventrix_Audit_Export/sales/sales_invoices.csv']!.replaceFirst('\uFEFF', '').split('\r\n').first, startsWith('id,number,'));
    expect(files['Inventrix_Audit_Export/taxation/tax_summaries.csv']!.replaceFirst('\uFEFF', '').trim(), startsWith('document_type,component,'));
    expect(files['Inventrix_Audit_Export/taxation/hsn_summaries.csv']!.replaceFirst('\uFEFF', '').trim(), startsWith('document_type,classification_system,'));
  });

  test('the tax configuration can change and the posted invoice export does not', () async {
    final before = await export(req(const ExportPeriod.all(), datasets: {ExportDataset.salesInvoices, ExportDataset.taxSummaries}));
    final a = await textFiles(before.valueOrNull!.fileName);
    await db.customStatement('UPDATE tax_components SET rate_basis_points = 2500, name = \'Renamed\'');
    await db.customStatement('UPDATE tax_rules SET is_active = 0');
    final after = await export(req(const ExportPeriod.all(), datasets: {ExportDataset.salesInvoices, ExportDataset.taxSummaries}));
    final b = await textFiles(after.valueOrNull!.fileName);
    for (final path in [
      'Inventrix_Audit_Export/sales/sales_invoices.csv',
      'Inventrix_Audit_Export/sales/sales_invoice_items.csv',
      'Inventrix_Audit_Export/taxation/tax_summaries.csv',
    ]) {
      expect(b[path], a[path], reason: path);
    }
  });

  test('exporting does not change the business data', () async {
    Future<List<String>> snapshot() async {
      final out = <String>[];
      for (final t in ['sales_invoices', 'sales_invoice_items', 'products', 'stock_movements', 'tax_components', 'invoice_item_tax_components']) {
        final rows = await db.customSelect('SELECT * FROM $t ORDER BY 1').get();
        out.add('$t:${rows.map((r) => r.data.toString()).join('|')}');
      }
      return out;
    }

    final before = await snapshot();
    await export(req(const ExportPeriod.all()));
    expect(await snapshot(), before);
  });

  test('the export is recorded in the history and in the audit trail', () async {
    final r = await export(req(ExportPeriod.financialYear(2026)));
    final history = (await DriftExportHistoryRepository(db).list()).valueOrNull!;
    expect(history.single.id, r.valueOrNull!.id);
    expect(history.single.integrityStatus, 'verified');
    expect(history.single.period.label, 'FY 2026-27');
    expect(history.single.datasets, contains(ExportDataset.hsnSummaries));
    final logged = await db
        .customSelect("SELECT COUNT(*) AS c FROM audit_events WHERE event_type = 'data_export.created'")
        .getSingle();
    expect(logged.read<int>('c'), 1);
    final chain = await VerifyAuditChain(repository: DriftAuditEventRepository(db), hasher: hasher)();
    expect(chain.valueOrNull!.isValid, isTrue);
  });

  test('a tampered audit chain is stated in the export', () async {
    await db.customStatement('DROP TRIGGER trg_audit_events_no_update');
    await db.customStatement("UPDATE audit_events SET new_values = '{\"x\":1}' WHERE seq = 2");
    final r = await export(req(const ExportPeriod.all(), datasets: {ExportDataset.auditTrail}));
    expect(r.valueOrNull!.chainStatus, 'broken');
  });

  test('XLSX output of real data opens as a workbook with the data in it', () async {
    final r = await export(req(const ExportPeriod.all(), format: ExportFormat.xlsx, datasets: {ExportDataset.salesInvoices}));
    final parts = zip.decode(store.files[r.valueOrNull!.fileName]!).valueOrNull!;
    expect(utf8.decode(parts['xl/worksheets/sheet2.xml']!), contains('INV-1'));
  });
}
