import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_position.dart';
import 'package:inventrix/features/inventory/domain/services/stock_calculator.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);
Quantity units(int n) => Quantity.fromUnits(n);
StockPosition empty() => StockPosition.empty(inr(0));

void main() {
  group('stockIn', () {
    test('adds quantity and value', () {
      final p = StockCalculator.stockIn(empty(), units(10), inr(5000));
      expect(p.position.quantity, units(10));
      expect(p.position.value, inr(5000));
      expect(p.quantityDelta, units(10));
      expect(p.costDelta, inr(5000));
    });

    test('accumulates across receipts at different costs', () {
      var position = StockCalculator.stockIn(
        empty(),
        units(10),
        inr(1000),
      ).position;
      position = StockCalculator.stockIn(
        position,
        units(10),
        inr(3000),
      ).position;
      expect(position.quantity, units(20));
      expect(position.value, inr(4000));
      expect(position.averageCost, inr(200));
    });

    test('supports fractional quantities', () {
      final p = StockCalculator.stockIn(
        empty(),
        const Quantity.fromMilli(2500),
        inr(1000),
      );
      expect(p.position.quantity.milli, 2500);
      expect(p.position.averageCost, inr(400));
    });

    test(
      'accepts free stock (zero cost) but not negative cost or quantity',
      () {
        expect(
          StockCalculator.stockIn(empty(), units(1), inr(0)).position.value,
          inr(0),
        );
        expect(
          () => StockCalculator.stockIn(empty(), units(1), inr(-1)),
          throwsArgumentError,
        );
        expect(
          () => StockCalculator.stockIn(empty(), Quantity.zero, inr(1)),
          throwsArgumentError,
        );
      },
    );
  });

  group('stockOut', () {
    final base = StockCalculator.stockIn(
      empty(),
      units(10),
      inr(5000),
    ).position;

    test('removes at the average cost and records negative deltas', () {
      final r = StockCalculator.stockOut(
        productId: 'p',
        position: base,
        quantity: units(4),
      ).valueOrNull!;
      expect(r.position.quantity, units(6));
      expect(r.position.value, inr(3000));
      expect(r.quantityDelta, units(-4));
      expect(r.costDelta, inr(-2000));
    });

    test('average cost is unchanged by sales', () {
      final r = StockCalculator.stockOut(
        productId: 'p',
        position: base,
        quantity: units(5),
      ).valueOrNull!;
      expect(r.position.averageCost, base.averageCost);
    });

    test('rejects more than is on hand and reports the numbers', () {
      final r = StockCalculator.stockOut(
        productId: 'p1',
        position: base,
        quantity: units(11),
      );
      final failure = r.failureOrNull as InsufficientStockFailure;
      expect(failure.productId, 'p1');
      expect(failure.requestedMilli, 11000);
      expect(failure.availableMilli, 10000);
    });

    test('rejects any stock-out from an empty position', () {
      final r = StockCalculator.stockOut(
        productId: 'p',
        position: empty(),
        quantity: const Quantity.fromMilli(1),
      );
      expect(r.failureOrNull, isA<InsufficientStockFailure>());
    });

    test('taking everything takes the whole value and leaves zero', () {
      final r = StockCalculator.stockOut(
        productId: 'p',
        position: base,
        quantity: units(10),
      ).valueOrNull!;
      expect(r.position.quantity, Quantity.zero);
      expect(r.position.value, inr(0));
      expect(r.position.averageCost, isNull);
    });

    test('rejects zero or negative quantities', () {
      expect(
        () => StockCalculator.stockOut(
          productId: 'p',
          position: base,
          quantity: Quantity.zero,
        ),
        throwsArgumentError,
      );
    });
  });

  group('rounding (weighted average cost edge cases)', () {
    test('3 units for 10.00 sold one by one: no value is lost or created', () {
      var position = StockCalculator.stockIn(
        empty(),
        units(3),
        inr(1000),
      ).position;
      final cogs = <int>[];
      for (var i = 0; i < 3; i++) {
        final r = StockCalculator.stockOut(
          productId: 'p',
          position: position,
          quantity: units(1),
        ).valueOrNull!;
        cogs.add(-r.costDelta.minorUnits);
        position = r.position;
      }
      expect(cogs, [333, 334, 333]);
      expect(cogs.reduce((a, b) => a + b), 1000);
      expect(position.value, inr(0));
    });

    test('the last unit absorbs residual rounding', () {
      var position = StockCalculator.stockIn(
        empty(),
        units(7),
        inr(100),
      ).position;
      var total = 0;
      for (var i = 0; i < 7; i++) {
        final r = StockCalculator.stockOut(
          productId: 'p',
          position: position,
          quantity: units(1),
        ).valueOrNull!;
        total += -r.costDelta.minorUnits;
        position = r.position;
      }
      expect(total, 100);
      expect(position.value, inr(0));
    });

    test('fractional quantities keep exact totals', () {
      var position = StockCalculator.stockIn(
        empty(),
        const Quantity.fromMilli(3333),
        inr(999),
      ).position;
      var total = 0;
      while (position.quantity.isPositive) {
        final take = position.quantity.milli >= 1000
            ? const Quantity.fromMilli(1000)
            : position.quantity;
        final r = StockCalculator.stockOut(
          productId: 'p',
          position: position,
          quantity: take,
        ).valueOrNull!;
        total += -r.costDelta.minorUnits;
        position = r.position;
      }
      expect(total, 999);
    });

    test('a tiny quantity out of a large value still rounds sanely', () {
      final position = StockCalculator.stockIn(
        empty(),
        units(1000),
        inr(1),
      ).position;
      final r = StockCalculator.stockOut(
        productId: 'p',
        position: position,
        quantity: units(1),
      ).valueOrNull!;
      expect(r.costDelta.minorUnits, 0);
      expect(r.position.value, inr(1));
    });

    test('costAtAverage for the full quantity equals the value', () {
      final position = StockCalculator.stockIn(
        empty(),
        units(3),
        inr(1000),
      ).position;
      expect(StockCalculator.costAtAverage(position, units(3)), inr(1000));
      expect(StockCalculator.costAtAverage(position, units(1)), inr(333));
      expect(
        () => StockCalculator.costAtAverage(position, units(4)),
        throwsArgumentError,
      );
    });
  });

  group('randomized invariants', () {
    test('quantity never goes negative; value stays consistent; full cycles '
        'conserve cost exactly', () {
      var seed = 12345;
      int next(int max) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        return seed % max;
      }

      for (var round = 0; round < 200; round++) {
        var position = empty();
        var costIn = 0;
        var costOut = 0;
        var ledgerQty = 0;
        var ledgerValue = 0;
        final steps = 5 + next(30);
        for (var i = 0; i < steps; i++) {
          if (next(3) == 0 || position.quantity.isZero) {
            final qty = Quantity.fromMilli(1 + next(5000));
            final cost = inr(next(20000));
            final r = StockCalculator.stockIn(position, qty, cost);
            position = r.position;
            costIn += cost.minorUnits;
            ledgerQty += r.quantityDelta.milli;
            ledgerValue += r.costDelta.minorUnits;
          } else {
            final qty = Quantity.fromMilli(
              1 + next(position.quantity.milli + 500),
            );
            final r = StockCalculator.stockOut(
              productId: 'p',
              position: position,
              quantity: qty,
            );
            if (qty > position.quantity) {
              expect(r.failureOrNull, isA<InsufficientStockFailure>());
              continue;
            }
            final posting = r.valueOrNull!;
            position = posting.position;
            costOut += -posting.costDelta.minorUnits;
            ledgerQty += posting.quantityDelta.milli;
            ledgerValue += posting.costDelta.minorUnits;
          }
          expect(position.quantity.isNegative, isFalse);
          expect(position.value.isNegative, isFalse);
          if (position.quantity.isZero) {
            expect(position.value.minorUnits, 0);
          }
          expect(ledgerQty, position.quantity.milli);
          expect(ledgerValue, position.value.minorUnits);
        }
        // Drain the stock: total cost out must equal total cost in.
        if (position.quantity.isPositive) {
          final r = StockCalculator.stockOut(
            productId: 'p',
            position: position,
            quantity: position.quantity,
          ).valueOrNull!;
          costOut += -r.costDelta.minorUnits;
          position = r.position;
        }
        expect(position.quantity.isZero, isTrue);
        expect(position.value.minorUnits, 0);
        expect(costOut, costIn);
      }
    });
  });
}
