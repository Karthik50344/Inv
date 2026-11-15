import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../../support/inventory_fixture.dart';

void main() {
  late InventoryFixture f;

  setUp(() => f = InventoryFixture());

  Future<String> stocked() async {
    final p = await f.addProduct();
    await f.openingStock(productId: p.id, quantity: '10', unitCost: '5');
    await f.adjustStock(
      productId: p.id,
      direction: StockAdjustmentDirection.stockOut,
      quantity: '4',
      reason: 'Count',
    );
    return p.id;
  }

  Money inr(int minor) =>
      Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

  StockBalance corrupt(String id, {int milli = 99000, int value = 1}) =>
      StockBalance(
        productId: id,
        quantityOnHand: Quantity.fromMilli(milli),
        inventoryValue: inr(value),
      );

  test('a consistent database reports no mismatches', () async {
    await stocked();
    final r = (await f.reconcile()).valueOrNull!;
    expect(r.isConsistent, isTrue);
    expect(r.productsChecked, 1);
  });

  test('an empty database is consistent', () async {
    final r = (await f.reconcile()).valueOrNull!;
    expect(r.isConsistent, isTrue);
    expect(r.productsChecked, 0);
  });

  test('detects a wrong balance and reports expected vs actual', () async {
    final id = await stocked();
    f.inventory.balances[id] = corrupt(id);
    final r = (await f.reconcile()).valueOrNull!;
    final mismatch = r.mismatches.single;
    expect(mismatch.productId, id);
    expect(mismatch.expectedQuantity.milli, 6000);
    expect(mismatch.expectedValue.minorUnits, 3000);
    expect(mismatch.actualQuantity.milli, 99000);
    expect(mismatch.balanceMissing, isFalse);
  });

  test('detects a missing balance row', () async {
    final id = await stocked();
    f.inventory.balances.remove(id);
    final r = (await f.reconcile()).valueOrNull!;
    expect(r.mismatches.single.balanceMissing, isTrue);
    expect(r.mismatches.single.expectedQuantity.milli, 6000);
  });

  test('detects a balance with no ledger behind it', () async {
    final p = await f.addProduct(name: 'Ghost', sku: 'G-1');
    f.inventory.balances[p.id] = corrupt(p.id, milli: 1000, value: 100);
    final r = (await f.reconcile()).valueOrNull!;
    expect(r.mismatches.single.expectedQuantity.isZero, isTrue);
    expect(r.mismatches.single.actualQuantity.milli, 1000);
  });

  test(
    'a missing balance for a ledger that nets to zero is harmless',
    () async {
      final p = await f.addProduct();
      await f.openingStock(productId: p.id, quantity: '2', unitCost: '5');
      await f.adjustStock(
        productId: p.id,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '2',
        reason: 'Count',
      );
      f.inventory.balances.remove(p.id);
      expect((await f.reconcile()).valueOrNull!.isConsistent, isTrue);
    },
  );

  group('repair', () {
    test(
      'rewrites balances from the ledger and audits each correction',
      () async {
        final id = await stocked();
        f.inventory.balances[id] = corrupt(id);
        final auditBefore = f.audit.entries.length;
        final fixed = await f.repair();
        expect(fixed.valueOrNull, 1);
        final b = f.inventory.balances[id]!;
        expect(b.quantityOnHand.milli, 6000);
        expect(b.inventoryValue.minorUnits, 3000);
        expect(f.audit.entries.length, auditBefore + 1);
        expect(f.audit.entries.last.action, 'balance_repaired');
        expect((await f.reconcile()).valueOrNull!.isConsistent, isTrue);
      },
    );

    test('restores a missing balance row', () async {
      final id = await stocked();
      f.inventory.balances.remove(id);
      await f.repair();
      expect(f.inventory.balances[id]!.quantityOnHand.milli, 6000);
    });

    test('is a no-op when everything is consistent', () async {
      await stocked();
      final auditBefore = f.audit.entries.length;
      final fixed = await f.repair();
      expect(fixed.valueOrNull, 0);
      expect(f.audit.entries.length, auditBefore);
    });

    test('never changes the ledger', () async {
      final id = await stocked();
      f.inventory.balances[id] = corrupt(id);
      final ledgerBefore = List.of(f.inventory.ledger);
      await f.repair();
      expect(f.inventory.ledger, ledgerBefore);
    });

    test('refuses to "repair" a ledger that nets negative', () async {
      final id = await stocked();
      f.inventory.balances[id] = corrupt(id);
      // Simulate a corrupted ledger: an outbound row with no matching stock.
      f.inventory.ledger.add(
        StockMovement(
          id: 'corrupt',
          productId: id,
          type: StockMovementType.adjustmentOut,
          quantityDelta: const Quantity.fromMilli(-50000),
          totalCost: inr(-100),
          unitCost: inr(0),
          reason: 'corrupt',
          occurredAt: f.clock.now(),
          createdAt: f.clock.now(),
        ),
      );
      final r = await f.repair();
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.inventory.balances[id]!.quantityOnHand.milli, 99000);
    });

    test('a failing audit write rolls back the repair', () async {
      final id = await stocked();
      f.inventory.balances[id] = corrupt(id);
      f.audit.recordFailure = const DatabaseFailure('audit unavailable');
      final r = await f.repair();
      expect(r.isFailure, isTrue);
      expect(f.inventory.balances[id]!.quantityOnHand.milli, 99000);
    });
  });
}
