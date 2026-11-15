import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/domain_exception.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

void main() {
  group('Quantity', () {
    test('stores milli-units and converts whole units', () {
      expect(Quantity.fromUnits(3).milli, 3000);
      expect(Quantity.zero.isZero, isTrue);
    });

    test('parses decimals within the unit precision', () {
      expect(Quantity.tryParse('1.5')?.milli, 1500);
      expect(Quantity.tryParse('0.001')?.milli, 1);
      expect(Quantity.tryParse('2')?.milli, 2000);
      expect(Quantity.tryParse('-0.25')?.milli, -250);
    });

    test('rejects over-precise or malformed input', () {
      expect(Quantity.tryParse('1.2345'), isNull);
      expect(Quantity.tryParse('1.5', maxDecimalPlaces: 0), isNull);
      expect(Quantity.tryParse('1.50', maxDecimalPlaces: 1)?.milli, 1500);
      expect(Quantity.tryParse('x'), isNull);
    });

    test('adds, subtracts and compares', () {
      const a = Quantity.fromMilli(1500);
      const b = Quantity.fromMilli(500);
      expect((a + b).milli, 2000);
      expect((b - a).milli, -1000);
      expect((b - a).isNegative, isTrue);
      expect(a > b, isTrue);
      expect(b < a, isTrue);
      expect(a >= a, isTrue);
      expect(a <= b, isFalse);
      expect(a.compareTo(b), 1);
      expect(a.negate().milli, -1500);
      expect((b - a).abs().milli, 1000);
    });

    test('throws on overflow', () {
      const big = Quantity.fromMilli(9223372036854775807);
      expect(
        () => big + const Quantity.fromMilli(1),
        throwsA(isA<ArithmeticOverflowException>()),
      );
    });

    test('formats trimmed and fixed', () {
      expect(const Quantity.fromMilli(1500).toDecimalString(), '1.5');
      expect(const Quantity.fromMilli(2000).toDecimalString(), '2');
      expect(const Quantity.fromMilli(1).toDecimalString(), '0.001');
      expect(const Quantity.fromMilli(-1500).toDecimalString(), '-1.5');
      expect(const Quantity.fromMilli(1500).toFixedString(2), '1.50');
      expect(const Quantity.fromMilli(1235).toFixedString(2), '1.24');
      expect(const Quantity.fromMilli(2000).toFixedString(0), '2');
    });

    test('reports whether a value fits a unit precision', () {
      expect(const Quantity.fromMilli(1500).fitsDecimalPlaces(1), isTrue);
      expect(const Quantity.fromMilli(1250).fitsDecimalPlaces(1), isFalse);
      expect(const Quantity.fromMilli(1250).fitsDecimalPlaces(3), isTrue);
      expect(const Quantity.fromMilli(2000).fitsDecimalPlaces(0), isTrue);
      expect(const Quantity.fromMilli(-1500).fitsDecimalPlaces(0), isFalse);
    });

    test('has value equality', () {
      expect(const Quantity.fromMilli(5), const Quantity.fromMilli(5));
      expect(
        const Quantity.fromMilli(5).hashCode,
        const Quantity.fromMilli(5).hashCode,
      );
    });
  });
}
