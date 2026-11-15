import '../support/fakes.dart';
import '../support/payment_guard_fake.dart';
import 'data_test_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/customers/data/repositories/drift_customer_repository.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/services/stock_operation_support.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/reconcile_inventory.dart';
import 'package:inventrix/features/returns/data/repositories/drift_return_repository.dart';
import 'package:inventrix/features/sales/data/repositories/drift_sales_repository.dart';
import 'package:inventrix/features/sales/domain/entities/sales_filter.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/domain/services/sales_line_builder.dart';
import 'package:inventrix/features/sales/domain/services/sales_stock_check.dart';
import 'package:inventrix/features/sales/domain/usecases/get_customer_receivable.dart';
import 'package:inventrix/features/sales/domain/usecases/post_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/save_sales_draft.dart';
import 'package:inventrix/features/sales/domain/usecases/transition_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/void_sale.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/data/drift_document_sequence_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Audit repository that can be switched to fail, to prove atomicity.
class _SwitchableAudit implements AuditLogRepository {
  _SwitchableAudit(this._real);
  final AuditLogRepository _real;
  bool failing = false;

  @override
  Future<Result<void>> record(AuditEntry entry) async => failing
      ? const Result.failure(DatabaseFailure('audit unavailable'))
      : _real.record(entry);

  @override
  Future<Result<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) => _real.forEntity(entityType, entityId, limit: limit);
}

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  late DataHarness h;
  late DriftInventoryRepository inventory;
  late DriftSalesRepository sales;
  late DriftCustomerRepository customers;
  late _SwitchableAudit audit;
  late SaveSalesDraft save;
  late TransitionSale transition;
  late PostSale post;
  late VoidSale voidSale;
  late GetCustomerReceivable receivable;
  late ReconcileInventory reconcile;
  late AdjustStock adjust;

  Future<void> stockUp(
    String productId,
    String qty, {
    String cost = '4',
  }) async {
    final r = await adjust(
      productId: productId,
      direction: StockAdjustmentDirection.stockIn,
      quantity: qty,
      reason: 'test stock',
      unitCost: cost,
    );
    expect(r.isSuccess, isTrue);
  }

  Future<int> count(String table) async {
    final row = await h.db
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  Future<Quantity> onHand(String productId) async =>
      (await inventory.getBalance(productId)).valueOrNull!.quantityOnHand;

  SalesLineInput line(String qty, {String price = '10', String id = 'p1'}) =>
      SalesLineInput(productId: id, quantity: qty, unitPrice: price);

  Future<String> draft(
    List<SalesLineInput> lines, {
    String? id,
    String? customer = 's1',
  }) async {
    final result = await save(
      SalesDraftInput(
        id: id,
        customerId: customer,
        invoiceDate: DateTime.utc(2026, 2, 3),
        dueDate: DateTime.utc(2026, 3, 3),
        customerReference: 'INV-77',
        notes: 'Note',
        lines: lines,
      ),
    );
    return result.valueOrNull!.id;
  }

  setUp(() async {
    h = DataHarness();
    inventory = DriftInventoryRepository(h.db, h.settings, h.products);
    sales = DriftSalesRepository(h.db, h.settings);
    customers = DriftCustomerRepository(h.db, h.settings);
    audit = _SwitchableAudit(DriftAuditLogRepository(h.db));
    final tx = DriftTransactionRunner(h.db);
    final sequences = DriftDocumentSequenceRepository(h.db);
    final ids = SequentialIds();
    final clock = FakeClock();
    final builder = SalesLineBuilder(
      products: h.products,
      units: h.units,
      taxRates: h.taxRates,
    );
    save = SaveSalesDraft(
      sales: sales,
      customers: customers,
      lineBuilder: builder,
      stockCheck: SalesStockCheck(inventory: inventory),
      settings: h.settings,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    transition = TransitionSale(
      sales: sales,
      settings: h.settings,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    post = PostSale(
      sales: sales,
      customers: customers,
      products: h.products,
      inventory: inventory,
      sequences: sequences,
      settings: h.settings,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    voidSale = VoidSale(
      sales: sales,
      inventory: inventory,
      audit: audit,
      payments: const NoPaymentsGuard(),
      returns: DriftReturnRepository(h.db),
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    receivable = GetCustomerReceivable(sales: sales, customers: customers);
    reconcile = ReconcileInventory(inventory: inventory);
    adjust = AdjustStock(
      support: StockOperationSupport(
        products: h.products,
        units: h.units,
        settings: h.settings,
      ),
      inventory: inventory,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    await h.units.create(unit());
    await h.products.create(product());
    await h.products.create(product(id: 'p2', sku: 'SKU-2', name: 'Saw'));
    await stockUp('p1', '100');
    await stockUp('p2', '100');
    await customers.create(
      Customer(
        id: 's1',
        name: 'Acme Traders',
        openingBalance: inr(5000),
        createdAt: t0,
        updatedAt: t0,
      ),
    );
  });
  tearDown(() => h.close());

  test('a draft round-trips with its lines and snapshots', () async {
    final id = await draft([
      SalesLineInput(
        productId: 'p1',
        quantity: '3',
        unitPrice: '12.50',
        discountKind: DiscountKind.percent,
        discountValue: '10',
      ),
      line('2', id: 'p2'),
    ]);
    final loaded = (await sales.getById(id)).valueOrNull!;
    expect(loaded.status, DocumentStatus.draft);
    expect(loaded.number, isNull);
    expect(loaded.customerName, 'Acme Traders');
    expect(loaded.customerReference, 'INV-77');
    expect(loaded.dueDate, DateTime.utc(2026, 3, 3));
    expect(loaded.lines.length, 2);
    expect(loaded.lines.first.productName, 'Hammer');
    expect(loaded.lines.first.discount, Discount.percent(1000));
    // 3 x 12.50 = 37.50, 10% off = 3.75 -> 33.75; + 2 x 10.00 = 20.00
    expect(loaded.totals.total, inr(5375));
    expect(await count('stock_movements'), 2); // only the test stock
  });

  test('a draft above the stock is refused and nothing is saved', () async {
    final r = await save(
      SalesDraftInput(
        customerId: 's1',
        invoiceDate: DateTime.utc(2026, 2, 3),
        lines: [line('101')],
      ),
    );
    expect(r.failureOrNull, isA<ValidationFailure>());
    expect(await count('sales_invoices'), 0);
  });

  test('a walk-in sale is stored without a customer', () async {
    final id = await draft([line('1')], customer: null);
    final posted = (await post(id)).valueOrNull!;
    expect(posted.customerId, isNull);
    expect(posted.customerName, 'Walk-in customer');
    final stored = (await sales.getById(id)).valueOrNull!;
    expect(stored.customerId, isNull);
    expect((await receivable('s1')).valueOrNull!.sales, inr(0));
  });

  test('editing a draft replaces its lines', () async {
    final id = await draft([line('1'), line('2', id: 'p2')]);
    await draft([line('7')], id: id);
    final loaded = (await sales.getById(id)).valueOrNull!;
    expect(loaded.lines.length, 1);
    expect(loaded.lines.single.quantity, Quantity.fromUnits(7));
    expect(await count('sales_invoice_items'), 1);
    expect(await count('sales_invoices'), 1);
  });

  test('posting updates stock, ledger, number and audit together', () async {
    final id = await draft([line('10', price: '10'), line('4', id: 'p2')]);
    final posted = (await post(id)).valueOrNull!;
    expect(posted.status, DocumentStatus.posted);
    expect(posted.number, 'INV-000001');
    expect(await onHand('p1'), Quantity.fromUnits(90));
    expect(await onHand('p2'), Quantity.fromUnits(96));
    expect(await count('stock_movements'), 4);
    final movement = await h.db
        .customSelect(
          'SELECT source_type, source_id, source_line_id, movement_type, '
          'quantity_delta_milli, total_cost_minor FROM stock_movements '
          "WHERE product_id = 'p1' AND source_id IS NOT NULL",
        )
        .getSingle();
    expect(movement.read<String>('movement_type'), 'sale');
    expect(movement.read<int>('quantity_delta_milli'), -10000);
    expect(movement.read<int>('total_cost_minor'), -4000);
    expect(movement.read<String>('source_type'), 'sales_invoice');
    expect(movement.read<String>('source_id'), id);
    expect((await reconcile()).valueOrNull!.isConsistent, isTrue);
    final trail = (await audit.forEntity('sales_invoice', id)).valueOrNull!;
    expect(
      trail.map((e) => e.action),
      containsAll(['draft_created', 'posted']),
    );
  });

  test('numbers are sequential across invoices', () async {
    final a = (await post(await draft([line('1')]))).valueOrNull!;
    final b = (await post(await draft([line('1')]))).valueOrNull!;
    expect(a.number, 'INV-000001');
    expect(b.number, 'INV-000002');
  });

  test('posting twice is rejected and adds no stock', () async {
    final id = await draft([line('5')]);
    (await post(id)).valueOrNull!;
    final again = await post(id);
    expect(again.failureOrNull, isA<ValidationFailure>());
    expect(await onHand('p1'), Quantity.fromUnits(95));
    expect(await count('stock_movements'), 3);
  });

  test('a failure while posting rolls back status, number and stock', () async {
    final id = await draft([line('5'), line('2', id: 'p2')]);
    audit.failing = true;
    expect((await post(id)).isFailure, isTrue);
    audit.failing = false;
    final loaded = (await sales.getById(id)).valueOrNull!;
    expect(loaded.status, DocumentStatus.draft);
    expect(loaded.number, isNull);
    expect(await count('stock_movements'), 2);
    expect(await onHand('p1'), Quantity.fromUnits(100));
    expect(await count('document_sequences'), 0);
    expect((await post(id)).valueOrNull!.number, 'INV-000001');
  });

  test('a posted sale is immutable at the database level', () async {
    final id = await draft([line('5')]);
    (await post(id)).valueOrNull!;
    expect(
      (await save(
        SalesDraftInput(
          id: id,
          customerId: 's1',
          invoiceDate: DateTime.utc(2026, 2, 3),
          lines: [line('9')],
        ),
      )).failureOrNull,
      isA<ValidationFailure>(),
    );
    // Even a direct draft overwrite is refused by the repository.
    final loaded = (await sales.getById(id)).valueOrNull!;
    expect(
      (await sales.saveDraft(loaded)).failureOrNull,
      isA<ValidationFailure>(),
    );
    expect(
      (await sales.getById(id)).valueOrNull!.lines.single.quantity,
      Quantity.fromUnits(5),
    );
  });

  test('posting more than the stock is rejected and rolls back', () async {
    final id = await draft([line('60'), line('40', id: 'p2')]);
    await adjust(
      productId: 'p2',
      direction: StockAdjustmentDirection.stockOut,
      quantity: '90',
      reason: 'Lost',
    );
    final r = await post(id);
    expect(r.failureOrNull, isA<InsufficientStockFailure>());
    expect(await onHand('p1'), Quantity.fromUnits(100));
    expect(await onHand('p2'), Quantity.fromUnits(10));
    expect((await sales.getById(id)).valueOrNull!.status, DocumentStatus.draft);
    expect(await count('document_sequences'), 0);
    expect((await reconcile()).valueOrNull!.isConsistent, isTrue);
  });

  test('voiding puts the stock back and keeps the document', () async {
    final id = await draft([line('10', price: '10')]);
    (await post(id)).valueOrNull!;
    final voided = (await voidSale(id, reason: 'Wrong')).valueOrNull!;
    expect(voided.status, DocumentStatus.voided);
    expect(voided.number, 'INV-000001');
    expect(voided.voidReason, 'Wrong');
    expect(await onHand('p1'), Quantity.fromUnits(100));
    expect(await count('stock_movements'), 4);
    expect(
      (await inventory.getBalance('p1')).valueOrNull!.inventoryValue,
      inr(40000),
    );
    expect((await reconcile()).valueOrNull!.isConsistent, isTrue);
    expect(
      (await voidSale(id, reason: 'again')).failureOrNull,
      isA<ValidationFailure>(),
    );
  });

  test('cancelled drafts never change stock or consume numbers', () async {
    final id = await draft([line('5')]);
    (await transition(id, SaleAction.cancel)).valueOrNull!;
    expect((await post(id)).failureOrNull, isA<ValidationFailure>());
    expect(await count('stock_movements'), 2);
    expect(await count('document_sequences'), 0);
  });

  test('approval workflow persists each step', () async {
    await h.settings.setSalesApprovalRequired(true);
    final id = await draft([line('2')]);
    expect((await post(id)).failureOrNull, isA<ValidationFailure>());
    (await transition(id, SaleAction.submit)).valueOrNull!;
    (await transition(id, SaleAction.approve)).valueOrNull!;
    expect((await post(id)).valueOrNull!.status, DocumentStatus.posted);
  });

  test('search filters by text, status and customer', () async {
    final a = await draft([line('1')]);
    final b = await draft([line('2')]);
    (await post(b)).valueOrNull!;
    var list = (await sales.search(const SalesFilter())).valueOrNull!;
    expect(list.length, 2);
    list = (await sales.search(
      const SalesFilter(status: DocumentStatus.posted),
    )).valueOrNull!;
    expect(list.single.id, b);
    list = (await sales.search(
      const SalesFilter(query: 'INV-000001'),
    )).valueOrNull!;
    expect(list.single.id, b);
    list = (await sales.search(
      const SalesFilter(query: 'inv-77'),
    )).valueOrNull!;
    expect(list.length, 2);
    list = (await sales.search(const SalesFilter(query: '100%'))).valueOrNull!;
    expect(list, isEmpty);
    list = (await sales.search(
      const SalesFilter(customerId: 'other'),
    )).valueOrNull!;
    expect(list, isEmpty);
    expect(a, isNotEmpty);
  });

  test('customer receivable = opening balance + posted sales', () async {
    final a = await draft([line('2', price: '50')]);
    final b = await draft([line('1', price: '30')]);
    await draft([line('9', price: '99')]);
    (await post(a)).valueOrNull!;
    (await post(b)).valueOrNull!;
    var p = (await receivable('s1')).valueOrNull!;
    expect(p.sales, inr(13000));
    expect(p.outstanding, inr(18000));
    (await voidSale(b, reason: 'x')).valueOrNull!;
    p = (await receivable('s1')).valueOrNull!;
    expect(p.outstanding, inr(15000));
  });

  test('history survives product and customer edits', () async {
    final id = await draft([line('2')]);
    (await post(id)).valueOrNull!;
    await h.db.customStatement(
      "UPDATE products SET name = 'Renamed', sku = 'NEW-SKU' WHERE id = 'p1'",
    );
    await h.db.customStatement(
      "UPDATE customers SET name = 'Renamed Co' WHERE id = 's1'",
    );
    final loaded = (await sales.getById(id)).valueOrNull!;
    expect(loaded.customerName, 'Acme Traders');
    expect(loaded.lines.single.productName, 'Hammer');
    expect(loaded.lines.single.sku, 'SKU-1');
  });

  test('database stays consistent', () async {
    final id = await draft([line('2')]);
    (await post(id)).valueOrNull!;
    expect(await h.db.integrityCheck(), ['ok']);
  });
}
