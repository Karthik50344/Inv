import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/sales/data/repositories/drift_sales_repository.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/taxation/data/repositories/drift_tax_repository.dart';
import 'package:inventrix/features/taxation/domain/entities/line_tax_snapshot.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/tax_line_service.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../core/database/database_test_helpers.dart';

class _NoSettings implements SettingsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

/// End-to-end over the real schema: tax configuration -> engine -> draft
/// invoice -> post -> configuration change -> the posted invoice is
/// unchanged. Written without a Flutter SDK: not yet executed.
void main() {
  late AppDatabase db;
  late DriftSalesRepository sales;
  late TaxLineService taxLines;

  Future<void> seedTax({int cgst = 900, int sgst = 900}) async {
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
      "INSERT INTO tax_components (id, tax_rule_id, name, component_type, rate_basis_points, calculation_order, is_compound, is_recoverable, is_active, created_at, updated_at) VALUES ('cg', 'rule', 'CGST', 'cgst', $cgst, 1, 0, 0, 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tax_components (id, tax_rule_id, name, component_type, rate_basis_points, calculation_order, is_compound, is_recoverable, is_active, created_at, updated_at) VALUES ('sg', 'rule', 'SGST', 'sgst', $sgst, 2, 0, 0, 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO app_settings (key, value, updated_at) VALUES ('tax_country_code', 'IN', 1), ('tax_region_code', 'KA', 1)",
    );
  }

  Future<SalesLine> buildLine(String id) async {
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
      classification: const ClassificationSnapshot(
        system: 'hsn',
        code: '8471',
        description: 'Computers',
      ),
    );
  }

  SalesInvoice invoice(List<SalesLine> lines) => SalesInvoice(
    id: 'inv1',
    customerName: 'Walk-in customer',
    status: DocumentStatus.draft,
    invoiceDate: DateTime.utc(2026, 6, 1),
    lines: lines,
    totals: SalesTotals.fromLines(lines, zero: inr(0)),
    createdAt: DateTime.utc(2026, 6, 1),
    updatedAt: DateTime.utc(2026, 6, 1),
  );

  Future<int> componentRows() async => (await db
      .customSelect('SELECT COUNT(*) AS c FROM invoice_item_tax_components')
      .getSingle()).read<int>('c');

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    await insertUnit(db, 'u1');
    await insertProduct(db, 'p1', sku: 'A');
    await seedTax();
    sales = DriftSalesRepository(db, _NoSettings());
    taxLines = TaxLineService(repository: DriftTaxRepository(db));
  });

  tearDown(() => db.close());

  test('a taxed draft stores its snapshot, components and classification', () async {
    final line = await buildLine('l1');
    expect((await sales.saveDraft(invoice([line]))).isSuccess, isTrue);

    expect(await componentRows(), 2);
    final read = (await sales.getById('inv1')).valueOrNull!.lines.single;
    expect(read.taxSnapshot, line.taxSnapshot);
    expect(read.classification!.label, 'HSN 8471');
    expect(read.tax, inr(3600)); // 2 x 100.00 at 9% + 9%
    expect(read.taxName, 'CGST + SGST');
    final item = await db
        .customSelect("SELECT tax_treatment, tax_category_id FROM sales_invoice_items WHERE id = 'l1'")
        .getSingle();
    expect(item.read<String>('tax_treatment'), 'standard_rated');
    expect(item.read<String>('tax_category_id'), 'cat');
  });

  test('saving the draft again replaces the component rows', () async {
    await sales.saveDraft(invoice([await buildLine('l1')]));
    await sales.saveDraft(invoice([await buildLine('l2')]));
    expect(await componentRows(), 2);
    final ids = (await db
        .customSelect('SELECT DISTINCT item_id FROM invoice_item_tax_components')
        .get()).map((r) => r.read<String>('item_id'));
    expect(ids, ['l2']);
  });

  test('after posting, components cannot be added, changed or deleted', () async {
    await sales.saveDraft(invoice([await buildLine('l1')]));
    await sales.markPosted('inv1', number: 'INV-1', at: DateTime.utc(2026, 6, 1));
    await expectLater(
      db.customStatement("UPDATE invoice_item_tax_components SET amount_minor = 1"),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement('DELETE FROM invoice_item_tax_components'),
      throwsA(anything),
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO invoice_item_tax_components (id, document_type, item_id, component_no, rule_id, component_id, name, component_type, calculation_method, taxable_minor, amount_minor, is_compound, is_recoverable) VALUES ('x', 'sales', 'l1', 9, 'rule', 'cg', 'X', 'custom', 'percentage', 1, 1, 0, 0)",
      ),
      throwsA(anything),
    );
    expect(await componentRows(), 2);
  });

  test('changing the tax configuration never changes a posted invoice', () async {
    final line = await buildLine('l1');
    await sales.saveDraft(invoice([line]));
    await sales.markPosted('inv1', number: 'INV-1', at: DateTime.utc(2026, 6, 1));
    final before = (await sales.getById('inv1')).valueOrNull!;

    // Rates change, the rule is switched off, the category is deactivated.
    await db.customStatement('UPDATE tax_components SET rate_basis_points = 2500');
    await db.customStatement("UPDATE tax_components SET name = 'Renamed'");
    await db.customStatement('UPDATE tax_rules SET is_active = 0');
    await db.customStatement('UPDATE tax_categories SET is_active = 0');

    final after = (await sales.getById('inv1')).valueOrNull!;
    expect(after, before);
    final snap = after.lines.single.taxSnapshot!;
    expect(snap.components.map((c) => c.name), ['CGST', 'SGST']);
    expect(snap.components.map((c) => c.rateBasisPoints), [900, 900]);
    expect(after.totals.tax, inr(3600));

    // New documents see the new configuration (the category is now inactive).
    final fresh = await taxLines.calculate(
      productTaxCategoryId: 'cat',
      productTaxOverrideId: null,
      type: TaxTransactionType.sale,
      date: DateTime.utc(2026, 6, 2),
      unitPrice: inr(10000),
      quantity: Quantity.fromUnits(1),
      priceIncludesTax: false,
      discount: const Discount.none(),
    );
    expect(fresh.isFailure, isTrue);
  });

  test('a legacy line without a snapshot still saves and reads back', () async {
    final base = await buildLine('l1');
    final legacy = SalesLine(
      id: 'l1',
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
      taxRateBp: 1800,
      taxName: 'GST 18%',
      amounts: base.amounts,
    );
    await sales.saveDraft(invoice([legacy]));
    final read = (await sales.getById('inv1')).valueOrNull!.lines.single;
    expect(read.taxSnapshot, isNull);
    expect(read.classification, isNull);
    expect(await componentRows(), 0);
  });

  test('the snapshot text stored on the line decodes to the same value', () async {
    final line = await buildLine('l1');
    await sales.saveDraft(invoice([line]));
    final stored = (await db
        .customSelect("SELECT tax_snapshot_json AS j FROM sales_invoice_items WHERE id = 'l1'")
        .getSingle()).read<String>('j');
    expect(LineTaxSnapshot.decode(stored), line.taxSnapshot);
  });
}
