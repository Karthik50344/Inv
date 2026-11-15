import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/domain_exception.dart';
import 'package:inventrix/core/utils/decimal_text.dart';
import 'package:inventrix/core/utils/rounding.dart';

void main() {
  group('divideRounded (half away from zero)', () {
    test('rounds exact, below-half and above-half values', () {
      expect(divideRounded(4, 2), 2);
      expect(divideRounded(1, 3), 0);
      expect(divideRounded(2, 3), 1);
    });

    test('rounds halves away from zero for every sign combination', () {
      expect(divideRounded(5, 2), 3);
      expect(divideRounded(-5, 2), -3);
      expect(divideRounded(5, -2), -3);
      expect(divideRounded(-5, -2), 3);
      expect(divideRounded(7, 2), 4);
    });

    test('rejects a zero divisor', () {
      expect(() => divideRounded(1, 0), throwsArgumentError);
    });
  });

  group('roundedMulDiv', () {
    test('uses exact intermediate arithmetic', () {
      expect(
        roundedMulDiv(4000000000000000000, 1000, 1000),
        4000000000000000000,
      );
    });

    test('throws when the result exceeds 64 bits', () {
      expect(
        () => roundedMulDiv(9000000000000000000, 2, 1),
        throwsA(isA<ArithmeticOverflowException>()),
      );
    });
  });

  group('checked arithmetic', () {
    test('adds and subtracts normally', () {
      expect(checkedAdd(2, 3), 5);
      expect(checkedSub(2, 3), -1);
    });

    test('detects overflow instead of wrapping', () {
      const max = 9223372036854775807;
      expect(
        () => checkedAdd(max, 1),
        throwsA(isA<ArithmeticOverflowException>()),
      );
      expect(
        () => checkedSub(-max, 2),
        throwsA(isA<ArithmeticOverflowException>()),
      );
    });
  });

  group('pow10', () {
    test('computes powers and rejects out-of-range exponents', () {
      expect(pow10(0), 1);
      expect(pow10(3), 1000);
      expect(pow10(18), 1000000000000000000);
      expect(() => pow10(19), throwsRangeError);
      expect(() => pow10(-1), throwsRangeError);
    });
  });

  group('decimal text', () {
    test('parses plain decimals into scaled integers', () {
      expect(parseScaledDecimal('12.5', scale: 2), 1250);
      expect(parseScaledDecimal('-0.05', scale: 2), -5);
      expect(parseScaledDecimal('.5', scale: 2), 50);
      expect(parseScaledDecimal('7', scale: 0), 7);
      expect(parseScaledDecimal('12.500', scale: 2), 1250);
    });

    test('rejects malformed or over-precise input', () {
      expect(parseScaledDecimal('', scale: 2), isNull);
      expect(parseScaledDecimal('-', scale: 2), isNull);
      expect(parseScaledDecimal('abc', scale: 2), isNull);
      expect(parseScaledDecimal('1,000.00', scale: 2), isNull);
      expect(parseScaledDecimal('12.345', scale: 2), isNull);
      expect(parseScaledDecimal('1e5', scale: 2), isNull);
      expect(parseScaledDecimal('99999999999999999999', scale: 2), isNull);
    });

    test('formats scaled integers', () {
      expect(formatScaledDecimal(123456, scale: 2), '1234.56');
      expect(formatScaledDecimal(-5, scale: 2), '-0.05');
      expect(formatScaledDecimal(123, scale: 0), '123');
      expect(formatScaledDecimal(1235, scale: 3, fractionDigits: 2), '1.24');
      expect(formatScaledDecimal(5, scale: 1, fractionDigits: 3), '0.500');
    });
  });
}
