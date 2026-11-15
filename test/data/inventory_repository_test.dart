import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/inventory/data/repositories/drift_inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_position.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../core/database/database_test_helpers.dart';
import 'data_test_support.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

StockMovement movement(
  String id, {
  String productId = 'p1',
  StockMovementType type = StockMovementType.purchase,
  int milli = 10000,
  int cost = 5000,
  String? reason,
  DateTime? at,
}) => StockMovement(
  id: id,
  productId: productId,
  type: type,
  quantityDelta: Quantity.fromMilli(milli),
  totalCost: inr(cost),
  unitCost: inr(0),
  reason: reason,
  occurredAt: at ?? t0,
  createdAt: at ?? t0,
);

StockPosition position(int milli, int value) =>
    StockPosition(quantity: Quantity.fromMilli(milli), value: inr(value));

void main() {
  late DataHarness h;
  late DriftInventoryRepository inventory;
  late DriftAuditLogRepository audit;
  late DriftTransactionRunner tx;

  setUp(() async {
    h = DataHarness();
    inventory = DriftInventoryRepository(h.db, h.settings, h.products);
    audit = DriftAuditLogRepository(h.db);
    tx = DriftTransactionRunner(h.db);
    await h.units.create(unit());
    await h.products.create(product());
  });
  tearDown(() => h.close());

  test('a new product has an empty balance', () async {
    final balance = (await inventory.getBalance('p1')).valueOrNull!;
    expect(balance.quantityOnHand.isZero, isTrue);
    expect(balance.inventoryValue.isZero, isTrue);
    expect(balance.averageCost, isNull);
  });

  test('applyMovement appends to the ledger and updates the balance', () async {
    expect((await inventory.hasMovements('p1')).valueOrNull, isFalse);
    final r = await tx.runResult(
      () async => (await inventory.applyMovement(
        movement('m1'),
        position(10000, 5000),
      )).getOrThrow(),
    );
    expect(r.isSuccess, isTrue);
    expect((await inventory.hasMovements('p1')).valueOrNull, isTrue);
    final balance = (await inventory.getBalance('p1')).valueOrNull!;
    expect(balance.quantityOnHand.milli, 10000);
    expect(balance.inventoryValue.minorUnits, 5000);
    expect(balance.averageCost?.minorUnits, 500);
  });

  test(
    'a failing balance write rolls the ledger entry back (atomic)',
    () async {
      // A sale that would leave negative stock violates the balance CHECK.
      final r = await tx.runResult(
        () async => (await inventory.applyMovement(
          movement(
            'm1',
            type: StockMovementType.sale,
            milli: -1000,
            cost: -100,
          ),
          position(-1000, 0),
        )).getOrThrow(),
      );
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect((await inventory.hasMovements('p1')).valueOrNull, isFalse);
      expect(
        (await inventory.allBalances())
            .valueOrNull!
            .single
            .quantityOnHand
            .isZero,
        isTrue,
      );
    },
  );

  test('the ledger is append-only', () async {
    await inventory.applyMovement(movement('m1'), position(10000, 5000));
    final update = await failureOf(
      () => h.db.customStatement("UPDATE stock_movements SET reason = 'x'"),
    );
    final delete = await failureOf(
      () => h.db.customStatement('DELETE FROM stock_movements'),
    );
    expect(update, isA<DatabaseFailure>());
    expect(delete, isA<DatabaseFailure>());
  });

  test('history is newest first and pageable', () async {
    for (var i = 0; i < 5; i++) {
      await inventory.applyMovement(
        movement(
          'm$i',
          milli: 1000,
          cost: 100,
          at: t0.add(Duration(minutes: i)),
        ),
        position(1000 * (i + 1), 100 * (i + 1)),
      );
    }
    final all = (await inventory.movements('p1')).valueOrNull!;
    expect(all.map((m) => m.id).toList(), ['m4', 'm3', 'm2', 'm1', 'm0']);
    final page = (await inventory.movements(
      'p1',
      limit: 2,
      offset: 2,
    )).valueOrNull!;
    expect(page.map((m) => m.id).toList(), ['m2', 'm1']);
  });

  test(
    'entries with the same timestamp keep insertion order (newest first)',
    () async {
      for (var i = 0; i < 3; i++) {
        await inventory.applyMovement(
          movement('s$i', milli: 1000, cost: 100),
          position(1000 * (i + 1), 100 * (i + 1)),
        );
      }
      final all = (await inventory.movements('p1')).valueOrNull!;
      expect(all.map((m) => m.id).toList(), ['s2', 's1', 's0']);
    },
  );

  test('movements round-trip all fields', () async {
    final original = movement(
      'm1',
      type: StockMovementType.adjustmentIn,
      reason: 'Found stock',
    );
    await inventory.applyMovement(original, position(10000, 5000));
    final loaded = (await inventory.movements('p1')).valueOrNull!.single;
    expect(loaded, original);
  });

  test('ledger totals sum per product', () async {
    await h.products.create(product(id: 'p2', sku: 'S2'));
    await inventory.applyMovement(
      movement('a', milli: 3000, cost: 300),
      position(3000, 300),
    );
    await inventory.applyMovement(
      movement('b', type: StockMovementType.sale, milli: -1000, cost: -100),
      position(2000, 200),
    );
    await inventory.applyMovement(
      movement('c', productId: 'p2', milli: 500, cost: 50),
      position(500, 50),
    );
    final totals = {
      for (final t in (await inventory.ledgerTotals()).valueOrNull!)
        t.productId: t,
    };
    expect(totals['p1']!.quantity.milli, 2000);
    expect(totals['p1']!.value.minorUnits, 200);
    expect(totals['p2']!.quantity.milli, 500);
  });

  test('stock list: statuses, search, category and valuation', () async {
    await h.categories.create(category());
    await h.products.create(
      product(id: 'p2', sku: 'S2', name: 'Saw', categoryId: 'c1'),
    );
    // p1 (reorder 5.000): 3 units => low; p2: 0 => out.
    await inventory.applyMovement(
      movement('a', milli: 3000, cost: 300),
      position(3000, 300),
    );
    final all = (await inventory.listStock(const StockFilter())).valueOrNull!;
    expect(all.map((i) => i.product.name).toList(), ['Hammer', 'Saw']);
    expect(all.first.status, StockStatus.low);
    expect(all.last.status, StockStatus.out);

    final low = await inventory.listStock(
      const StockFilter(status: StockStatusFilter.low),
    );
    expect(low.valueOrNull!.single.product.id, 'p1');
    final bySearch = await inventory.listStock(const StockFilter(query: 'saw'));
    expect(bySearch.valueOrNull!.single.product.id, 'p2');
    final byCategory = await inventory.listStock(
      const StockFilter(categoryId: 'c1'),
    );
    expect(byCategory.valueOrNull!.single.product.id, 'p2');

    final valuation = (await inventory.valuation()).valueOrNull!;
    expect(valuation.totalValue.minorUnits, 300);
    expect(valuation.productsInStock, 1);
    expect(valuation.lowStockCount, 1);
    expect(valuation.outOfStockCount, 1);
  });

  test('stock item for an unknown product is NotFound', () async {
    expect(
      (await inventory.getStockItem('ghost')).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('replaceBalance overwrites the balance only', () async {
    await inventory.applyMovement(
      movement('a', milli: 3000, cost: 300),
      position(3000, 300),
    );
    await inventory.replaceBalance('p1', position(1000, 100), t0);
    expect(
      (await inventory.getBalance('p1')).valueOrNull!.quantityOnHand.milli,
      1000,
    );
    expect((await inventory.movements('p1')).valueOrNull!.length, 1);
  });

  group('audit log', () {
    AuditEntry entry(String id, {DateTime? at, String summary = 'did it'}) =>
        AuditEntry(
          id: id,
          entityType: 'stock',
          entityId: 'p1',
          action: 'adjustmentIn',
          summary: summary,
          occurredAt: at ?? t0,
        );

    test('records and lists entries newest first', () async {
      await audit.record(entry('a1', at: t0));
      await audit.record(entry('a2', at: t0.add(const Duration(minutes: 1))));
      final list = (await audit.forEntity('stock', 'p1')).valueOrNull!;
      expect(list.map((e) => e.id).toList(), ['a2', 'a1']);
      expect((await audit.forEntity('stock', 'other')).valueOrNull, isEmpty);
    });

    test('is append-only', () async {
      await audit.record(entry('a1'));
      expect(
        await failureOf(
          () => h.db.customStatement("UPDATE audit_logs SET summary = 'x'"),
        ),
        isA<DatabaseFailure>(),
      );
      expect(
        await failureOf(() => h.db.customStatement('DELETE FROM audit_logs')),
        isA<DatabaseFailure>(),
      );
    });

    test('rolls back with the surrounding transaction', () async {
      final r = await tx.runResult<void>(() async {
        (await audit.record(entry('a1'))).getOrThrow();
        throw const FailureException(DatabaseFailure('later step failed'));
      });
      expect(r.isFailure, isTrue);
      expect((await audit.forEntity('stock', 'p1')).valueOrNull, isEmpty);
    });
  });
}
