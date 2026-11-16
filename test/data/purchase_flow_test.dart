import '../support/fakes.dart';
import '../support/payment_guard_fake.dart';
import 'data_test_support.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/usecases/reconcile_inventory.dart';
import 'package:inventrix/features/purchases/data/repositories/drift_purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_filter.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/features/purchases/domain/services/purchase_line_builder.dart';
import 'package:inventrix/features/purchases/domain/usecases/get_supplier_payable.dart';
import 'package:inventrix/features/purchases/domain/usecases/post_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/save_purchase_draft.dart';
import 'package:inventrix/features/purchases/domain/usecases/transition_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/void_purchase.dart';
import 'package:inventrix/features/returns/data/repositories/drift_return_repository.dart';
import 'package:inventrix/features/suppliers/data/repositories/drift_supplier_repository.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
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
  late DriftPurchaseRepository purchases;
  late DriftSupplierRepository suppliers;
  late _SwitchableAudit audit;
  late SavePurchaseDraft save;
  late TransitionPurchase transition;
  late PostPurchase post;
  late VoidPurchase voidPurchase;
  late GetSupplierPayable payable;
  late ReconcileInventory reconcile;

  Future<int> count(String table) async {
    final row = await h.db
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  Future<Quantity> onHand(String productId) async =>
      (await inventory.getBalance(productId)).valueOrNull!.quantityOnHand;

  PurchaseLineInput line(String qty, {String price = '10', String id = 'p1'}) =>
      PurchaseLineInput(productId: id, quantity: qty, unitPrice: price);

  Future<String> draft(List<PurchaseLineInput> lines, {String? id}) async {
    final result = await save(
      PurchaseDraftInput(
        id: id,
        supplierId: 's1',
        invoiceDate: DateTime.utc(2026, 2, 3),
        dueDate: DateTime.utc(2026, 3, 3),
        supplierReference: 'INV-77',
        notes: 'Note',
        lines: lines,
      ),
    );
    return result.valueOrNull!.id;
  }

  setUp(() async {
    h = DataHarness();
    inventory = DriftInventoryRepository(h.db, h.settings, h.products);
    purchases = DriftPurchaseRepository(h.db, h.settings);
    suppliers = DriftSupplierRepository(h.db, h.settings);
    audit = _SwitchableAudit(DriftAuditLogRepository(h.db));
    final tx = DriftTransactionRunner(h.db);
    final sequences = DriftDocumentSequenceRepository(h.db);
    final ids = SequentialIds();
    final clock = FakeClock();
    final builder = PurchaseLineBuilder(
      products: h.products,
      units: h.units,
      taxRates: h.taxRates,
    );
    save = SavePurchaseDraft(
      purchases: purchases,
      suppliers: suppliers,
      lineBuilder: builder,
      settings: h.settings,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    transition = TransitionPurchase(
      purchases: purchases,
      settings: h.settings,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    post = PostPurchase(
      purchases: purchases,
      suppliers: suppliers,
      products: h.products,
      inventory: inventory,
      sequences: sequences,
      settings: h.settings,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    voidPurchase = VoidPurchase(
      purchases: purchases,
      inventory: inventory,
      audit: audit,
      payments: const NoPaymentsGuard(),
      returns: DriftReturnRepository(h.db),
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    payable = GetSupplierPayable(purchases: purchases, suppliers: suppliers);
    reconcile = ReconcileInventory(inventory: inventory);
    await h.units.create(unit());
    await h.products.create(product());
    await h.products.create(product(id: 'p2', sku: 'SKU-2', name: 'Saw'));
    await suppliers.create(
      Supplier(
        id: 's1',
        name: 'Acme Supplies',
        openingBalance: inr(5000),
        createdAt: t0,
        updatedAt: t0,
      ),
    );
  });
  tearDown(() => h.close());

  test('a draft round-trips with its lines and snapshots', () async {
    final id = await draft([
      PurchaseLineInput(
        productId: 'p1',
        quantity: '3',
        unitPrice: '12.50',
        discountKind: DiscountKind.percent,
        discountValue: '10',
      ),
      line('2', id: 'p2'),
    ]);
    final loaded = (await purchases.getById(id)).valueOrNull!;
    expect(loaded.status, DocumentStatus.draft);
    expect(loaded.number, isNull);
    expect(loaded.supplierName, 'Acme Supplies');
    expect(loaded.supplierReference, 'INV-77');
    expect(loaded.dueDate, DateTime.utc(2026, 3, 3));
    expect(loaded.lines.length, 2);
    expect(loaded.lines.first.productName, 'Hammer');
    expect(loaded.lines.first.discount, Discount.percent(1000));
    // 3 x 12.50 = 37.50, 10% off = 3.75 -> 33.75; + 2 x 10.00 = 20.00
    expect(loaded.totals.total, inr(5375));
    expect(await count('stock_movements'), 0);
  });

  test('editing a draft replaces its lines', () async {
    final id = await draft([line('1'), line('2', id: 'p2')]);
    await draft([line('7')], id: id);
    final loaded = (await purchases.getById(id)).valueOrNull!;
    expect(loaded.lines.length, 1);
    expect(loaded.lines.single.quantity, Quantity.fromUnits(7));
    expect(await count('purchase_invoice_items'), 1);
    expect(await count('purchase_invoices'), 1);
  });

  test('posting updates stock, ledger, number and audit together', () async {
    final id = await draft([line('10', price: '10'), line('4', id: 'p2')]);
    final posted = (await post(id)).valueOrNull!;
    expect(posted.status, DocumentStatus.posted);
    expect(posted.number, 'PUR-000001');
    expect(await onHand('p1'), Quantity.fromUnits(10));
    expect(await onHand('p2'), Quantity.fromUnits(4));
    expect(await count('stock_movements'), 2);
    final movement = await h.db
        .customSelect(
          "SELECT source_type, source_id, source_line_id FROM stock_movements "
          "WHERE product_id = 'p1'",
        )
        .getSingle();
    expect(movement.read<String>('source_type'), 'purchase_invoice');
    expect(movement.read<String>('source_id'), id);
    expect((await reconcile()).valueOrNull!.isConsistent, isTrue);
    final trail = (await audit.forEntity('purchase_invoice', id)).valueOrNull!;
    expect(
      trail.map((e) => e.action),
      containsAll(['draft_created', 'posted']),
    );
  });

  test('numbers are sequential across invoices', () async {
    final a = (await post(await draft([line('1')]))).valueOrNull!;
    final b = (await post(await draft([line('1')]))).valueOrNull!;
    expect(a.number, 'PUR-000001');
    expect(b.number, 'PUR-000002');
  });

  test('posting twice is rejected and adds no stock', () async {
    final id = await draft([line('5')]);
    (await post(id)).valueOrNull!;
    final again = await post(id);
    expect(again.failureOrNull, isA<ValidationFailure>());
    expect(await onHand('p1'), Quantity.fromUnits(5));
    expect(await count('stock_movements'), 1);
  });

  test('a failure while posting rolls back status, number and stock', () async {
    final id = await draft([line('5'), line('2', id: 'p2')]);
    audit.failing = true;
    expect((await post(id)).isFailure, isTrue);
    audit.failing = false;
    final loaded = (await purchases.getById(id)).valueOrNull!;
    expect(loaded.status, DocumentStatus.draft);
    expect(loaded.number, isNull);
    expect(await count('stock_movements'), 0);
    expect(await count('document_sequences'), 0);
    expect((await post(id)).valueOrNull!.number, 'PUR-000001');
  });

  test('a posted purchase is immutable at the database level', () async {
    final id = await draft([line('5')]);
    (await post(id)).valueOrNull!;
    expect(
      (await save(
        PurchaseDraftInput(
          id: id,
          supplierId: 's1',
          invoiceDate: DateTime.utc(2026, 2, 3),
          lines: [line('9')],
        ),
      )).failureOrNull,
      isA<ValidationFailure>(),
    );
    // Even a direct draft overwrite is refused by the repository.
    final loaded = (await purchases.getById(id)).valueOrNull!;
    expect(
      (await purchases.saveDraft(loaded)).failureOrNull,
      isA<ValidationFailure>(),
    );
    expect(
      (await purchases.getById(id)).valueOrNull!.lines.single.quantity,
      Quantity.fromUnits(5),
    );
  });

  test('voiding reverses stock and keeps the document', () async {
    final id = await draft([line('10', price: '10')]);
    (await post(id)).valueOrNull!;
    final voided = (await voidPurchase(id, reason: 'Wrong')).valueOrNull!;
    expect(voided.status, DocumentStatus.voided);
    expect(voided.number, 'PUR-000001');
    expect(voided.voidReason, 'Wrong');
    expect(await onHand('p1'), Quantity.zero);
    expect(await count('stock_movements'), 2);
    expect((await reconcile()).valueOrNull!.isConsistent, isTrue);
    expect(
      (await voidPurchase(id, reason: 'again')).failureOrNull,
      isA<ValidationFailure>(),
    );
  });

  test('cancelled drafts never change stock or consume numbers', () async {
    final id = await draft([line('5')]);
    (await transition(id, PurchaseAction.cancel)).valueOrNull!;
    expect((await post(id)).failureOrNull, isA<ValidationFailure>());
    expect(await count('stock_movements'), 0);
    expect(await count('document_sequences'), 0);
  });

  test('approval workflow persists each step', () async {
    await h.settings.setPurchaseApprovalRequired(true);
    final id = await draft([line('2')]);
    expect((await post(id)).failureOrNull, isA<ValidationFailure>());
    (await transition(id, PurchaseAction.submit)).valueOrNull!;
    (await transition(id, PurchaseAction.approve)).valueOrNull!;
    expect((await post(id)).valueOrNull!.status, DocumentStatus.posted);
  });

  test('search filters by text, status and supplier', () async {
    final a = await draft([line('1')]);
    final b = await draft([line('2')]);
    (await post(b)).valueOrNull!;
    var list = (await purchases.search(const PurchaseFilter())).valueOrNull!;
    expect(list.length, 2);
    list = (await purchases.search(
      const PurchaseFilter(status: DocumentStatus.posted),
    )).valueOrNull!;
    expect(list.single.id, b);
    list = (await purchases.search(const PurchaseFilter(query: 'PUR-000001')))
        .valueOrNull!;
    expect(list.single.id, b);
    list = (await purchases.search(const PurchaseFilter(query: 'inv-77')))
        .valueOrNull!;
    expect(list.length, 2);
    list = (await purchases.search(const PurchaseFilter(query: '100%')))
        .valueOrNull!;
    expect(list, isEmpty);
    list = (await purchases.search(const PurchaseFilter(supplierId: 'other')))
        .valueOrNull!;
    expect(list, isEmpty);
    expect(a, isNotEmpty);
  });

  test('supplier payable = opening balance + posted purchases', () async {
    final a = await draft([line('2', price: '50')]);
    final b = await draft([line('1', price: '30')]);
    await draft([line('9', price: '99')]);
    (await post(a)).valueOrNull!;
    (await post(b)).valueOrNull!;
    var p = (await payable('s1')).valueOrNull!;
    expect(p.purchases, inr(13000));
    expect(p.outstanding, inr(18000));
    (await voidPurchase(b, reason: 'x')).valueOrNull!;
    p = (await payable('s1')).valueOrNull!;
    expect(p.outstanding, inr(15000));
  });

  test('history survives product and supplier edits', () async {
    final id = await draft([line('2')]);
    (await post(id)).valueOrNull!;
    await h.db.customStatement(
      "UPDATE products SET name = 'Renamed', sku = 'NEW-SKU' WHERE id = 'p1'",
    );
    await h.db.customStatement(
      "UPDATE suppliers SET name = 'Renamed Co' WHERE id = 's1'",
    );
    final loaded = (await purchases.getById(id)).valueOrNull!;
    expect(loaded.supplierName, 'Acme Supplies');
    expect(loaded.lines.single.productName, 'Hammer');
    expect(loaded.lines.single.sku, 'SKU-1');
  });

  test('database stays consistent', () async {
    final id = await draft([line('2')]);
    (await post(id)).valueOrNull!;
    expect(await h.db.integrityCheck(), ['ok']);
  });
}
