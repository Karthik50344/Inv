import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/shared/domain/services/line_calculator.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  group('tax-exclusive prices', () {
    test('adds tax on top of the net amount', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(10000),
        quantity: Quantity.fromUnits(3),
        priceIncludesTax: false,
        discount: const Discount.none(),
        taxRateBp: 1800,
      ).valueOrNull!;
      expect(a.gross, inr(30000));
      expect(a.discount, inr(0));
      expect(a.net, inr(30000));
      expect(a.tax, inr(5400));
      expect(a.total, inr(35400));
    });

    test('percentage discount comes off before tax', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(10000),
        quantity: Quantity.fromUnits(3),
        priceIncludesTax: false,
        discount: Discount.percent(1000),
        taxRateBp: 1800,
      ).valueOrNull!;
      expect(a.discount, inr(3000));
      expect(a.net, inr(27000));
      expect(a.tax, inr(4860));
      expect(a.total, inr(31860));
    });

    test('fixed discount comes off before tax', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(10000),
        quantity: Quantity.fromUnits(3),
        priceIncludesTax: false,
        discount: Discount.amount(inr(5000)),
        taxRateBp: 1800,
      ).valueOrNull!;
      expect(a.net, inr(25000));
      expect(a.tax, inr(4500));
      expect(a.total, inr(29500));
    });

    test('fractional quantity rounds the line once', () {
      // 3.33 x 0.333 = 1.10889 -> 1.11
      final a = LineCalculator.calculate(
        unitPrice: inr(333),
        quantity: const Quantity.fromMilli(333),
        priceIncludesTax: false,
        discount: const Discount.none(),
        taxRateBp: 0,
      ).valueOrNull!;
      expect(a.gross, inr(111));
      expect(a.total, inr(111));
    });

    test('tax rounds half away from zero', () {
      // 0.05 x 10% = 0.005 -> 0.01
      final a = LineCalculator.calculate(
        unitPrice: inr(5),
        quantity: Quantity.fromUnits(1),
        priceIncludesTax: false,
        discount: const Discount.none(),
        taxRateBp: 1000,
      ).valueOrNull!;
      expect(a.tax, inr(1));
    });

    test('tax-exempt (0%) adds nothing', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(999),
        quantity: Quantity.fromUnits(2),
        priceIncludesTax: false,
        discount: const Discount.none(),
        taxRateBp: 0,
      ).valueOrNull!;
      expect(a.tax, inr(0));
      expect(a.total, inr(1998));
    });
  });

  group('tax-inclusive prices', () {
    test('splits the price into net and tax', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(11800),
        quantity: Quantity.fromUnits(1),
        priceIncludesTax: true,
        discount: const Discount.none(),
        taxRateBp: 1800,
      ).valueOrNull!;
      expect(a.total, inr(11800));
      expect(a.net, inr(10000));
      expect(a.tax, inr(1800));
    });

    test('net + tax always equals the total, even when rounding', () {
      // 100.00 incl. 18%: net = 84.745.. -> 84.75, tax = 15.25
      final a = LineCalculator.calculate(
        unitPrice: inr(10000),
        quantity: Quantity.fromUnits(1),
        priceIncludesTax: true,
        discount: const Discount.none(),
        taxRateBp: 1800,
      ).valueOrNull!;
      expect(a.net, inr(8475));
      expect(a.tax, inr(1525));
      expect(a.net + a.tax, a.total);
    });

    test('discount applies to the inclusive amount', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(11800),
        quantity: Quantity.fromUnits(2),
        priceIncludesTax: true,
        discount: Discount.percent(5000),
        taxRateBp: 1800,
      ).valueOrNull!;
      expect(a.gross, inr(23600));
      expect(a.discount, inr(11800));
      expect(a.total, inr(11800));
      expect(a.net, inr(10000));
    });
  });

  group('edge cases', () {
    test('a 100% discount leaves nothing', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(5000),
        quantity: Quantity.fromUnits(4),
        priceIncludesTax: false,
        discount: Discount.percent(10000),
        taxRateBp: 1800,
      ).valueOrNull!;
      expect(a.net, inr(0));
      expect(a.tax, inr(0));
      expect(a.total, inr(0));
    });

    test('a free item is allowed', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(0),
        quantity: Quantity.fromUnits(1),
        priceIncludesTax: false,
        discount: const Discount.none(),
        taxRateBp: 1800,
      ).valueOrNull!;
      expect(a.total, inr(0));
    });

    test('a fixed discount above the line value is rejected', () {
      final result = LineCalculator.calculate(
        unitPrice: inr(1000),
        quantity: Quantity.fromUnits(1),
        priceIncludesTax: false,
        discount: Discount.amount(inr(1001)),
        taxRateBp: 0,
      );
      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors.keys.toList(), [
        'discount',
      ]);
    });

    test('a fixed discount equal to the line value is allowed', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(1000),
        quantity: Quantity.fromUnits(1),
        priceIncludesTax: false,
        discount: Discount.amount(inr(1000)),
        taxRateBp: 0,
      ).valueOrNull!;
      expect(a.total, inr(0));
    });

    test('large amounts stay exact', () {
      final a = LineCalculator.calculate(
        unitPrice: inr(99999999999),
        quantity: Quantity.fromUnits(1000),
        priceIncludesTax: false,
        discount: const Discount.none(),
        taxRateBp: 1800,
      ).valueOrNull!;
      expect(a.gross, inr(99999999999000));
      expect(a.tax, inr(17999999999820));
    });

    test('programmer errors throw', () {
      expect(
        () => LineCalculator.calculate(
          unitPrice: inr(100),
          quantity: Quantity.zero,
          priceIncludesTax: false,
          discount: const Discount.none(),
          taxRateBp: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => LineCalculator.calculate(
          unitPrice: inr(-1),
          quantity: Quantity.fromUnits(1),
          priceIncludesTax: false,
          discount: const Discount.none(),
          taxRateBp: 0,
        ),
        throwsArgumentError,
      );
    });
  });
}
