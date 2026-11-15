import 'package:inventrix/core/errors/domain_exception.dart';

/// Computes `(a * b) / divisor` using exact (BigInt) intermediate arithmetic
/// and rounds **half away from zero**.
///
/// Throws [ArgumentError] if [divisor] is zero and
/// [ArithmeticOverflowException] if the result does not fit in 64 bits.
int roundedMulDiv(int a, int b, int divisor) {
  if (divisor == 0) {
    throw ArgumentError.value(divisor, 'divisor', 'must not be zero');
  }
  final result = _roundedDivide(
    BigInt.from(a) * BigInt.from(b),
    BigInt.from(divisor),
  );
  if (!result.isValidInt) {
    throw const ArithmeticOverflowException();
  }
  return result.toInt();
}

/// Integer division rounding half away from zero.
int divideRounded(int numerator, int denominator) =>
    roundedMulDiv(numerator, 1, denominator);

/// `a + b` that throws [ArithmeticOverflowException] instead of wrapping.
int checkedAdd(int a, int b) {
  final result = a + b;
  if (((a ^ result) & (b ^ result)) < 0) {
    throw const ArithmeticOverflowException();
  }
  return result;
}

/// `a - b` that throws [ArithmeticOverflowException] instead of wrapping.
int checkedSub(int a, int b) {
  final result = a - b;
  if (((a ^ b) & (a ^ result)) < 0) {
    throw const ArithmeticOverflowException();
  }
  return result;
}

/// Returns 10 raised to [exponent] (0 to 18).
int pow10(int exponent) {
  if (exponent < 0 || exponent > 18) {
    throw RangeError.range(exponent, 0, 18, 'exponent');
  }
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 10;
  }
  return result;
}

BigInt _roundedDivide(BigInt numerator, BigInt denominator) {
  final quotient = numerator ~/ denominator;
  final remainder = numerator.remainder(denominator);
  if (remainder == BigInt.zero) {
    return quotient;
  }
  final isHalfOrMore = remainder.abs() * BigInt.from(2) >= denominator.abs();
  if (!isHalfOrMore) {
    return quotient;
  }
  final awayFromZero = numerator.isNegative != denominator.isNegative
      ? -BigInt.one
      : BigInt.one;
  return quotient + awayFromZero;
}
