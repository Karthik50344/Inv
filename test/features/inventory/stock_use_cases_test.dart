import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';

import '../../support/domain_fixture.dart';
import '../../support/inventory_fixture.dart';

void main() {
  late InventoryFixture f;

  setUp(() => f = InventoryFixture());

  Future<void> adjust(
    String productId,
    StockAdjustmentDirection direction,
    String quantity, {
    String reason = 'Count',
    String unitCost = '',
  }) async {
    final r = await f.adjustStock(
      productId: productId,
      direction: direction,
      quantity: quantity,
      reason: reason,
      unitCost: unitCost,
    );
    expect(r.isSuccess, isTrue, reason: '${r.failureOrNull}');
  }

  group('opening stock', () {
    test('records an auditable opening movement and the balance', () async {
      final p = await f.addProduct();
      final r = await f.openingStock(
        productId: p.id,
        quantity: '10',
        unitCost: '12.50',
      );
      final m = r.valueOrNull!;
      expect(m.type, StockMovementType.openingStock);
      expect(m.quantityDelta.milli, 10000);
      expect(m.totalCost.minorUnits, 12500);
      expect(m.unitCost.minorUnits, 1250);
      final balance = f.inventory.balances[p.id]!;
      expect(balance.quantityOnHand.milli, 10000);
      expect(balance.inventoryValue.minorUnits, 12500);
      expect(f.inventory.ledger.length, 1);
      expect(f.audit.entries.single.action, 'opening_stock');
      expect(f.audit.entries.single.entityId, p.id);
    });

    test('unit cost defaults to the purchase price', () async {
      final p = await f.addProduct(purchase: '8');
      final r = await f.openingStock(productId: p.id, quantity: '5');
      expect(r.valueOrNull?.totalCost.minorUnits, 4000);
    });

    test('is allowed once, before any other movement', () async {
      final p = await f.addProduct();
      await f.openingStock(productId: p.id, quantity: '5');
      final again = await f.openingStock(productId: p.id, quantity: '5');
      expect(again.failureOrNull, isA<ValidationFailure>());
      expect(f.inventory.ledger.length, 1);

      final q = await f.addProduct(name: 'Saw', sku: 'S-1');
      await adjust(q.id, StockAdjustmentDirection.stockIn, '2');
      final late = await f.openingStock(productId: q.id, quantity: '5');
      expect(late.failureOrNull, isA<ValidationFailure>());
    });

    test('validates quantity and cost', () async {
      final p = await f.addProduct();
      final r = await f.openingStock(
        productId: p.id,
        quantity: '0',
        unitCost: 'abc',
      );
      expect(fieldErrorsOf(r).containsKey('quantity'), isTrue);
      expect(fieldErrorsOf(r).containsKey('unitCost'), isTrue);
      final fractional = await f.openingStock(productId: p.id, quantity: '1.5');
      expect(fieldErrorsOf(fractional).containsKey('quantity'), isTrue);
      expect(f.inventory.ledger, isEmpty);
    });

    test('respects fractional units', () async {
      final p = await f.addProduct(name: 'Rice', sku: 'R-1', unitId: 'kg');
      final r = await f.openingStock(
        productId: p.id,
        quantity: '2.5',
        unitCost: '40',
      );
      expect(r.valueOrNull?.quantityDelta.milli, 2500);
      expect(r.valueOrNull?.totalCost.minorUnits, 10000);
      final tooPrecise = await f.openingStock(
        productId: p.id,
        quantity: '1.2345',
      );
      expect(fieldErrorsOf(tooPrecise).containsKey('quantity'), isTrue);
    });

    test('rejects archived and unknown products', () async {
      final p = await f.addProduct();
      await ArchiveProduct(products: f.products, clock: f.clock)(p.id);
      expect(
        (await f.openingStock(productId: p.id, quantity: '1')).failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        (await f.openingStock(productId: 'ghost', quantity: '1')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('adjustments', () {
    test(
      'stock-in with an explicit cost updates the weighted average',
      () async {
        final p = await f.addProduct();
        await f.openingStock(productId: p.id, quantity: '10', unitCost: '10');
        await adjust(
          p.id,
          StockAdjustmentDirection.stockIn,
          '10',
          unitCost: '30',
        );
        final b = f.inventory.balances[p.id]!;
        expect(b.quantityOnHand.milli, 20000);
        expect(b.inventoryValue.minorUnits, 40000);
        expect(b.averageCost?.minorUnits, 2000);
      },
    );

    test(
      'stock-in without a cost uses the current average (average unchanged)',
      () async {
        final p = await f.addProduct();
        await f.openingStock(productId: p.id, quantity: '10', unitCost: '20');
        await adjust(p.id, StockAdjustmentDirection.stockIn, '5');
        final b = f.inventory.balances[p.id]!;
        expect(b.quantityOnHand.milli, 15000);
        expect(b.averageCost?.minorUnits, 2000);
      },
    );

    test('stock-in on an empty product uses the purchase price', () async {
      final p = await f.addProduct(purchase: '7');
      await adjust(p.id, StockAdjustmentDirection.stockIn, '3');
      expect(f.inventory.balances[p.id]!.inventoryValue.minorUnits, 2100);
    });

    test('stock-out values removed units at the average cost', () async {
      final p = await f.addProduct();
      await f.openingStock(productId: p.id, quantity: '10', unitCost: '5');
      final r = await f.adjustStock(
        productId: p.id,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '4',
        reason: 'Damaged',
      );
      final m = r.valueOrNull!;
      expect(m.type, StockMovementType.adjustmentOut);
      expect(m.quantityDelta.milli, -4000);
      expect(m.totalCost.minorUnits, -2000);
      expect(m.reason, 'Damaged');
      final b = f.inventory.balances[p.id]!;
      expect(b.quantityOnHand.milli, 6000);
      expect(b.inventoryValue.minorUnits, 3000);
    });

    test('cannot remove more than is on hand; nothing changes', () async {
      final p = await f.addProduct();
      await f.openingStock(productId: p.id, quantity: '3');
      final ledgerBefore = f.inventory.ledger.length;
      final auditBefore = f.audit.entries.length;
      final r = await f.adjustStock(
        productId: p.id,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '4',
        reason: 'Oops',
      );
      final failure = r.failureOrNull as InsufficientStockFailure;
      expect(failure.availableMilli, 3000);
      expect(failure.requestedMilli, 4000);
      expect(f.inventory.ledger.length, ledgerBefore);
      expect(f.audit.entries.length, auditBefore);
      expect(f.inventory.balances[p.id]!.quantityOnHand.milli, 3000);
      expect(f.transactions.rolledBack, greaterThan(0));
    });

    test('removing all stock leaves zero quantity and zero value', () async {
      final p = await f.addProduct();
      await f.openingStock(productId: p.id, quantity: '3', unitCost: '3.33');
      await adjust(p.id, StockAdjustmentDirection.stockOut, '3');
      final b = f.inventory.balances[p.id]!;
      expect(b.quantityOnHand.isZero, isTrue);
      expect(b.inventoryValue.isZero, isTrue);
    });

    test('a reason is mandatory', () async {
      final p = await f.addProduct();
      await f.openingStock(productId: p.id, quantity: '3');
      final r = await f.adjustStock(
        productId: p.id,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '1',
        reason: '   ',
      );
      expect(fieldErrorsOf(r).containsKey('reason'), isTrue);
      final long = await f.adjustStock(
        productId: p.id,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '1',
        reason: 'x' * 201,
      );
      expect(fieldErrorsOf(long).containsKey('reason'), isTrue);
      expect(f.inventory.ledger.length, 1);
    });

    test('validates quantity precision and sign', () async {
      final p = await f.addProduct();
      final r = await f.adjustStock(
        productId: p.id,
        direction: StockAdjustmentDirection.stockIn,
        quantity: '-1',
        reason: 'x',
      );
      expect(fieldErrorsOf(r).containsKey('quantity'), isTrue);
      final fractional = await f.adjustStock(
        productId: p.id,
        direction: StockAdjustmentDirection.stockIn,
        quantity: '0.5',
        reason: 'x',
      );
      expect(fieldErrorsOf(fractional).containsKey('quantity'), isTrue);
    });

    test('every adjustment is ledgered and audited with its reason', () async {
      final p = await f.addProduct();
      await adjust(
        p.id,
        StockAdjustmentDirection.stockIn,
        '5',
        reason: 'Found',
      );
      expect(f.inventory.ledger.single.reason, 'Found');
      expect(f.audit.entries.single.summary.contains('Found'), isTrue);
      expect(f.audit.entries.single.action, 'adjustmentIn');
    });

    test('a failing audit write rolls the whole adjustment back', () async {
      final p = await f.addProduct();
      await f.openingStock(productId: p.id, quantity: '5', unitCost: '10');
      f.audit.recordFailure = const DatabaseFailure('audit table unavailable');
      final r = await f.adjustStock(
        productId: p.id,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '2',
        reason: 'Count',
      );
      expect(r.failureOrNull, isA<DatabaseFailure>());
      expect(f.inventory.ledger.length, 1);
      expect(f.inventory.balances[p.id]!.quantityOnHand.milli, 5000);
    });

    test(
      'a failing ledger write is reported and leaves no partial state',
      () async {
        final p = await f.addProduct();
        await f.openingStock(productId: p.id, quantity: '5', unitCost: '10');
        f.inventory.applyFailure = const DatabaseFailure('disk full');
        final r = await f.adjustStock(
          productId: p.id,
          direction: StockAdjustmentDirection.stockIn,
          quantity: '2',
          reason: 'Count',
        );
        expect(r.failureOrNull, isA<DatabaseFailure>());
        expect(f.audit.entries.length, 1);
        expect(f.inventory.balances[p.id]!.quantityOnHand.milli, 5000);
      },
    );

    test('never lets stock go negative across many operations', () async {
      final p = await f.addProduct();
      await f.openingStock(productId: p.id, quantity: '5', unitCost: '10');
      for (var i = 0; i < 10; i++) {
        await f.adjustStock(
          productId: p.id,
          direction: StockAdjustmentDirection.stockOut,
          quantity: '2',
          reason: 'loop',
        );
        expect(f.inventory.balances[p.id]!.quantityOnHand.isNegative, isFalse);
      }
      expect(f.inventory.balances[p.id]!.quantityOnHand.milli, 1000);
    });
  });

  group('ledger and balance stay consistent', () {
    test(
      'balance equals the sum of the ledger after mixed operations',
      () async {
        final p = await f.addProduct(name: 'Rice', sku: 'R-1', unitId: 'kg');
        await f.openingStock(
          productId: p.id,
          quantity: '10',
          unitCost: '33.33',
        );
        await adjust(p.id, StockAdjustmentDirection.stockOut, '3.333');
        await adjust(
          p.id,
          StockAdjustmentDirection.stockIn,
          '1.5',
          unitCost: '41',
        );
        await adjust(p.id, StockAdjustmentDirection.stockOut, '7.001');
        final report = (await f.reconcile()).valueOrNull!;
        expect(report.isConsistent, isTrue);
        expect(report.productsChecked, 1);
      },
    );
  });
}
