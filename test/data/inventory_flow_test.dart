import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/services/stock_operation_support.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/reconcile_inventory.dart';
import 'package:inventrix/features/inventory/domain/usecases/record_opening_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/repair_inventory_balances.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

import '../support/fakes.dart';
import 'data_test_support.dart';

/// An audit repository that always fails (to prove atomicity).
class _FailingAudit implements AuditLogRepository {
  @override
  Future<Result<void>> record(AuditEntry entry) async =>
      const Result.failure(DatabaseFailure('audit unavailable'));

  @override
  Future<Result<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) async => const Result.success([]);
}

void main() {
  late DataHarness h;
  late DriftInventoryRepository inventory;
  late DriftAuditLogRepository audit;
  late DriftTransactionRunner tx;
  late RecordOpeningStock opening;
  late AdjustStock adjust;
  late ReconcileInventory reconcile;
  late RepairInventoryBalances repair;

  Future<int> count(String table) async {
    final row = await h.db
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  AdjustStock buildAdjust(AuditLogRepository auditRepo) => AdjustStock(
    support: StockOperationSupport(
      products: h.products,
      units: h.units,
      settings: h.settings,
    ),
    inventory: inventory,
    audit: auditRepo,
    transactions: tx,
    ids: SequentialIds(),
    clock: FakeClock(),
  );

  setUp(() async {
    h = DataHarness();
    inventory = DriftInventoryRepository(h.db, h.settings, h.products);
    audit = DriftAuditLogRepository(h.db);
    tx = DriftTransactionRunner(h.db);
    final support = StockOperationSupport(
      products: h.products,
      units: h.units,
      settings: h.settings,
    );
    final ids = SequentialIds();
    final clock = FakeClock();
    opening = RecordOpeningStock(
      support: support,
      inventory: inventory,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    adjust = buildAdjust(audit);
    reconcile = ReconcileInventory(inventory: inventory);
    repair = RepairInventoryBalances(
      reconcile: reconcile,
      inventory: inventory,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    await h.units.create(unit());
    await h.units.create(unit(id: 'kg', symbol: 'kg', places: 3));
    await h.products.create(product());
  });
  tearDown(() => h.close());

  test(
    'opening stock, in and out are ledgered, audited and consistent',
    () async {
      expect(
        (await opening(
          productId: 'p1',
          quantity: '10',
          unitCost: '5',
        )).isSuccess,
        isTrue,
      );
      expect(
        (await adjust(
          productId: 'p1',
          direction: StockAdjustmentDirection.stockIn,
          quantity: '10',
          unitCost: '15',
          reason: 'Delivery',
        )).isSuccess,
        isTrue,
      );
      expect(
        (await adjust(
          productId: 'p1',
          direction: StockAdjustmentDirection.stockOut,
          quantity: '5',
          reason: 'Damaged',
        )).isSuccess,
        isTrue,
      );
      final balance = (await inventory.getBalance('p1')).valueOrNull!;
      // 10 @ 5 + 10 @ 15 = 200.00 over 20 => 10.00 avg; 5 out at 10.00.
      expect(balance.quantityOnHand.milli, 15000);
      expect(balance.inventoryValue.minorUnits, 15000);
      expect(await count('stock_movements'), 3);
      expect(await count('audit_logs'), 3);
      expect((await reconcile()).valueOrNull!.isConsistent, isTrue);
    },
  );

  test('insufficient stock leaves the database untouched', () async {
    await opening(productId: 'p1', quantity: '3', unitCost: '5');
    final movements = await count('stock_movements');
    final audits = await count('audit_logs');
    final r = await adjust(
      productId: 'p1',
      direction: StockAdjustmentDirection.stockOut,
      quantity: '4',
      reason: 'Oops',
    );
    expect(r.failureOrNull, isA<InsufficientStockFailure>());
    expect(await count('stock_movements'), movements);
    expect(await count('audit_logs'), audits);
    expect(
      (await inventory.getBalance('p1')).valueOrNull!.quantityOnHand.milli,
      3000,
    );
  });

  test(
    'a failing audit write rolls back the ledger entry and the balance',
    () async {
      await opening(productId: 'p1', quantity: '3', unitCost: '5');
      final r = await buildAdjust(_FailingAudit())(
        productId: 'p1',
        direction: StockAdjustmentDirection.stockIn,
        quantity: '2',
        unitCost: '9',
        reason: 'Count',
      );
      expect(r.failureOrNull, isA<DatabaseFailure>());
      expect(await count('stock_movements'), 1);
      expect(
        (await inventory.getBalance('p1')).valueOrNull!.quantityOnHand.milli,
        3000,
      );
    },
  );

  test('opening stock can be recorded only once', () async {
    await opening(productId: 'p1', quantity: '3');
    final again = await opening(productId: 'p1', quantity: '3');
    expect(again.failureOrNull, isA<ValidationFailure>());
    expect(await count('stock_movements'), 1);
  });

  test('fractional units keep exact totals through a full cycle', () async {
    await h.products.create(product(id: 'p2', sku: 'RICE', unitId: 'kg'));
    await opening(productId: 'p2', quantity: '3.333', unitCost: '0.30');
    var removed = 0;
    for (final q in ['1.111', '1.111', '1.111']) {
      final r = await adjust(
        productId: 'p2',
        direction: StockAdjustmentDirection.stockOut,
        quantity: q,
        reason: 'Sold loose',
      );
      removed += -r.valueOrNull!.totalCost.minorUnits;
    }
    final balance = (await inventory.getBalance('p2')).valueOrNull!;
    expect(balance.quantityOnHand.isZero, isTrue);
    expect(balance.inventoryValue.isZero, isTrue);
    // 3.333 kg at 0.30 = 0.9999 -> 100 minor units in, all of it out.
    expect(removed, 100);
  });

  test(
    'tampering with a balance is detected and repaired from the ledger',
    () async {
      await opening(productId: 'p1', quantity: '10', unitCost: '5');
      await h.db.customStatement(
        "UPDATE inventory_balances SET quantity_on_hand_milli = 99000 "
        "WHERE product_id = 'p1'",
      );
      final report = (await reconcile()).valueOrNull!;
      expect(report.mismatches.single.expectedQuantity.milli, 10000);
      expect(report.mismatches.single.actualQuantity.milli, 99000);

      expect((await repair()).valueOrNull, 1);
      expect((await reconcile()).valueOrNull!.isConsistent, isTrue);
      expect(
        (await inventory.getBalance('p1')).valueOrNull!.quantityOnHand.milli,
        10000,
      );
      final repairs = await h.db
          .customSelect(
            "SELECT COUNT(*) AS c FROM audit_logs WHERE action = 'balance_repaired'",
          )
          .getSingle();
      expect(repairs.read<int>('c'), 1);
      // The ledger itself was never touched.
      expect(await count('stock_movements'), 1);
    },
  );

  test('a deleted balance row is rebuilt by repair', () async {
    await opening(productId: 'p1', quantity: '4', unitCost: '5');
    await h.db.customStatement('DELETE FROM inventory_balances');
    expect(
      (await reconcile()).valueOrNull!.mismatches.single.balanceMissing,
      isTrue,
    );
    await repair();
    expect(
      (await inventory.getBalance('p1')).valueOrNull!.quantityOnHand.milli,
      4000,
    );
  });
}
