import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/domain_exception.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  group('construction and validation', () {
    test('rejects invalid currency codes and decimal places', () {
      expect(
        () => Money.fromMinor(1, currencyCode: 'inr', decimalPlaces: 2),
        throwsArgumentError,
      );
      expect(
        () => Money.fromMinor(1, currencyCode: 'INRX', decimalPlaces: 2),
        throwsArgumentError,
      );
      expect(
        () => Money.fromMinor(1, currencyCode: 'INR', decimalPlaces: 5),
        throwsArgumentError,
      );
      expect(
        () => Money.fromMinor(1, currencyCode: 'INR', decimalPlaces: -1),
        throwsArgumentError,
      );
    });

    test('zero and sign helpers', () {
      final zero = Money.zero(currencyCode: 'INR', decimalPlaces: 2);
      expect(zero.isZero, isTrue);
      expect(inr(5).isPositive, isTrue);
      expect(inr(-5).isNegative, isTrue);
      expect(inr(-5).abs(), inr(5));
      expect(inr(5).negate(), inr(-5));
    });

    test('value equality includes currency and decimal places', () {
      expect(inr(100), inr(100));
      expect(inr(100).hashCode, inr(100).hashCode);
      expect(
        inr(100) == Money.fromMinor(100, currencyCode: 'USD', decimalPlaces: 2),
        isFalse,
      );
      expect(
        inr(100) == Money.fromMinor(100, currencyCode: 'INR', decimalPlaces: 3),
        isFalse,
      );
    });
  });

  group('arithmetic and comparison', () {
    test('adds, subtracts and sums', () {
      expect(inr(150) + inr(250), inr(400));
      expect(inr(150) - inr(250), inr(-100));
      expect(
        Money.sum(
          [inr(1), inr(2), inr(3)],
          currencyCode: 'INR',
          decimalPlaces: 2,
        ),
        inr(6),
      );
      expect(
        Money.sum(const [], currencyCode: 'INR', decimalPlaces: 2),
        inr(0),
      );
    });

    test('rejects mixed currencies and decimal places', () {
      final usd = Money.fromMinor(1, currencyCode: 'USD', decimalPlaces: 2);
      final inr3 = Money.fromMinor(1, currencyCode: 'INR', decimalPlaces: 3);
      expect(() => inr(1) + usd, throwsA(isA<CurrencyMismatchException>()));
      expect(() => inr(1) - usd, throwsA(isA<CurrencyMismatchException>()));
      expect(() => inr(1) < usd, throwsA(isA<CurrencyMismatchException>()));
      expect(() => inr(1) + inr3, throwsA(isA<CurrencyMismatchException>()));
    });

    test('compares', () {
      expect(inr(1) < inr(2), isTrue);
      expect(inr(2) > inr(1), isTrue);
      expect(inr(2) >= inr(2), isTrue);
      expect(inr(3) <= inr(2), isFalse);
      expect(inr(1).compareTo(inr(2)), -1);
    });

    test('throws on overflow', () {
      expect(
        () => inr(9223372036854775807) + inr(1),
        throwsA(isA<ArithmeticOverflowException>()),
      );
    });

    test('handles large but valid amounts exactly', () {
      final large = inr(9000000000000000);
      expect(large + inr(1), inr(9000000000000001));
      expect(
        large.multiplyByQuantity(Quantity.fromUnits(1000)),
        inr(9000000000000000000),
      );
    });
  });

  group('price x quantity', () {
    test('multiplies by whole and fractional quantities', () {
      expect(inr(1999).multiplyByQuantity(Quantity.fromUnits(3)), inr(5997));
      expect(
        inr(100).multiplyByQuantity(const Quantity.fromMilli(333)),
        inr(33),
      );
    });

    test('zero quantity gives zero', () {
      expect(inr(1999).multiplyByQuantity(Quantity.zero), inr(0));
    });

    test('rounds half away from zero', () {
      expect(
        inr(333).multiplyByQuantity(const Quantity.fromMilli(500)),
        inr(167),
      );
      expect(
        inr(-333).multiplyByQuantity(const Quantity.fromMilli(500)),
        inr(-167),
      );
    });

    test('multiplyByInt', () {
      expect(inr(25).multiplyByInt(4), inr(100));
    });
  });

  group('perUnit', () {
    test('divides a total by a quantity, rounding once', () {
      expect(inr(1000).perUnit(Quantity.fromUnits(3)), inr(333));
      expect(inr(1001).perUnit(Quantity.fromUnits(2)), inr(501));
      expect(inr(1000).perUnit(const Quantity.fromMilli(500)), inr(2000));
    });

    test('rejects zero or negative quantities', () {
      expect(() => inr(1).perUnit(Quantity.zero), throwsArgumentError);
      expect(
        () => inr(1).perUnit(const Quantity.fromMilli(-1)),
        throwsArgumentError,
      );
    });
  });

  group('prorate', () {
    test('takes a rounded proportion', () {
      expect(
        inr(1000).prorate(Quantity.fromUnits(1), Quantity.fromUnits(3)),
        inr(333),
      );
      expect(
        inr(667).prorate(Quantity.fromUnits(1), Quantity.fromUnits(2)),
        inr(334),
      );
      expect(
        inr(1234).prorate(Quantity.fromUnits(2), Quantity.fromUnits(2)),
        inr(1234),
      );
      expect(inr(1234).prorate(Quantity.zero, Quantity.fromUnits(2)), inr(0));
    });

    test('rejects invalid proportions', () {
      expect(
        () => inr(1).prorate(Quantity.fromUnits(3), Quantity.fromUnits(2)),
        throwsArgumentError,
      );
      expect(
        () => inr(1).prorate(Quantity.zero, Quantity.zero),
        throwsArgumentError,
      );
      expect(
        () =>
            inr(1).prorate(const Quantity.fromMilli(-1), Quantity.fromUnits(1)),
        throwsArgumentError,
      );
    });
  });

  group('discount and tax', () {
    test('percentage of an amount rounds once', () {
      expect(inr(999).applyBasisPoints(1000), inr(100));
      expect(inr(10000).applyBasisPoints(0), inr(0));
      expect(inr(10000).applyBasisPoints(10000), inr(10000));
    });

    test('tax-exclusive tax', () {
      expect(inr(10000).applyBasisPoints(1800), inr(1800));
      expect(inr(333).applyBasisPoints(500), inr(17));
    });

    test('tax-inclusive extraction keeps net + tax = gross', () {
      expect(inr(11800).netOfGross(1800), inr(10000));
      expect(inr(11800).taxPortionOfGross(1800), inr(1800));
      expect(inr(100).netOfGross(500), inr(95));
      expect(inr(100).taxPortionOfGross(500), inr(5));
      expect(inr(105).taxPortionOfGross(500), inr(5));
      final gross = inr(12345);
      expect(gross.netOfGross(1200) + gross.taxPortionOfGross(1200), gross);
    });

    test('rejects negative basis points', () {
      expect(() => inr(1).applyBasisPoints(-1), throwsArgumentError);
      expect(() => inr(1).netOfGross(-1), throwsArgumentError);
    });
  });

  group('text conversion', () {
    test('formats plain strings by decimal places', () {
      expect(inr(123456).toPlainString(), '1234.56');
      expect(inr(-5).toPlainString(), '-0.05');
      expect(inr(0).toPlainString(), '0.00');
      expect(
        Money.fromMinor(
          123,
          currencyCode: 'JPY',
          decimalPlaces: 0,
        ).toPlainString(),
        '123',
      );
      expect(inr(1250).toString(), 'INR 12.50');
    });

    test('parses plain strings', () {
      Money? parse(String text) =>
          Money.tryParse(text, currencyCode: 'INR', decimalPlaces: 2);
      expect(parse('12.5'), inr(1250));
      expect(parse('-0.5'), inr(-50));
      expect(parse('12.345'), isNull);
      expect(parse('abc'), isNull);
      expect(parse(''), isNull);
    });
  });
}
