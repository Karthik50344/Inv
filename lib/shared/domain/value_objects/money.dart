import 'package:inventrix/core/errors/domain_exception.dart';
import 'package:inventrix/core/utils/decimal_text.dart';
import 'package:inventrix/core/utils/rounding.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

final RegExp _currencyPattern = RegExp(r'^[A-Z]{3}$');

/// Immutable monetary amount stored as integer minor units (e.g. paise or
/// cents) together with its currency code and decimal places.
///
/// No floating point is used anywhere. Every rounding step rounds half away
/// from zero. Combining amounts of different currencies or decimal places
/// throws [CurrencyMismatchException].
final class Money implements Comparable<Money> {
  const Money._(this.minorUnits, this.currencyCode, this.decimalPlaces);

  /// Creates an amount from [minorUnits].
  ///
  /// [currencyCode] must be a 3-letter uppercase code and [decimalPlaces]
  /// must be between 0 and 4.
  factory Money.fromMinor(
    int minorUnits, {
    required String currencyCode,
    required int decimalPlaces,
  }) {
    _validate(currencyCode, decimalPlaces);
    return Money._(minorUnits, currencyCode, decimalPlaces);
  }

  /// Creates a zero amount.
  factory Money.zero({
    required String currencyCode,
    required int decimalPlaces,
  }) => Money.fromMinor(
    0,
    currencyCode: currencyCode,
    decimalPlaces: decimalPlaces,
  );

  /// Parses plain decimal text such as `1234.50` (no grouping separators).
  ///
  /// Returns `null` if the text is malformed or has more fraction digits than
  /// [decimalPlaces].
  static Money? tryParse(
    String input, {
    required String currencyCode,
    required int decimalPlaces,
  }) {
    _validate(currencyCode, decimalPlaces);
    final minor = parseScaledDecimal(input, scale: decimalPlaces);
    return minor == null ? null : Money._(minor, currencyCode, decimalPlaces);
  }

  /// Sums [values]; returns zero for an empty iterable.
  static Money sum(
    Iterable<Money> values, {
    required String currencyCode,
    required int decimalPlaces,
  }) {
    var total = Money.zero(
      currencyCode: currencyCode,
      decimalPlaces: decimalPlaces,
    );
    for (final value in values) {
      total += value;
    }
    return total;
  }

  /// Amount in minor units.
  final int minorUnits;

  /// ISO 4217-style currency code, e.g. `INR`.
  final String currencyCode;

  /// Number of minor-unit digits (2 for INR/USD, 0 for JPY).
  final int decimalPlaces;

  /// Sum of two amounts.
  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money._(
      checkedAdd(minorUnits, other.minorUnits),
      currencyCode,
      decimalPlaces,
    );
  }

  /// Difference of two amounts.
  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money._(
      checkedSub(minorUnits, other.minorUnits),
      currencyCode,
      decimalPlaces,
    );
  }

  /// Whether this is smaller than [other].
  bool operator <(Money other) => compareTo(other) < 0;

  /// Whether this is smaller than or equal to [other].
  bool operator <=(Money other) => compareTo(other) <= 0;

  /// Whether this is greater than [other].
  bool operator >(Money other) => compareTo(other) > 0;

  /// Whether this is greater than or equal to [other].
  bool operator >=(Money other) => compareTo(other) >= 0;

  /// The amount with the opposite sign.
  Money negate() =>
      Money._(checkedSub(0, minorUnits), currencyCode, decimalPlaces);

  /// Absolute value.
  Money abs() => isNegative ? negate() : this;

  /// Multiplies a unit price by a [quantity] (price x quantity), rounding
  /// once to the nearest minor unit.
  Money multiplyByQuantity(Quantity quantity) => Money._(
    roundedMulDiv(minorUnits, quantity.milli, Quantity.factor),
    currencyCode,
    decimalPlaces,
  );

  /// Multiplies by a whole number.
  Money multiplyByInt(int factor) => Money._(
    roundedMulDiv(minorUnits, factor, 1),
    currencyCode,
    decimalPlaces,
  );

  /// Returns [basisPoints] (1% = 100) of this amount, rounded once.
  ///
  /// Used for percentage discounts and tax-exclusive tax:
  /// `net.applyBasisPoints(1800)` is 18% of `net`.
  Money applyBasisPoints(int basisPoints) {
    _requireBasisPoints(basisPoints);
    return Money._(
      roundedMulDiv(minorUnits, basisPoints, 10000),
      currencyCode,
      decimalPlaces,
    );
  }

  /// This total divided by [quantity], rounded once (e.g. an average unit
  /// cost). Throws [ArgumentError] when [quantity] is not positive.
  Money perUnit(Quantity quantity) {
    if (!quantity.isPositive) {
      throw ArgumentError.value(quantity, 'quantity', 'must be positive');
    }
    return Money._(
      roundedMulDiv(minorUnits, Quantity.factor, quantity.milli),
      currencyCode,
      decimalPlaces,
    );
  }

  /// The share `part / whole` of this amount, rounded once. Used to take a
  /// proportion of an inventory value. Requires `0 <= part <= whole`.
  Money prorate(Quantity part, Quantity whole) {
    if (!whole.isPositive || part.isNegative || part > whole) {
      throw ArgumentError('Require 0 <= part <= whole and whole > 0.');
    }
    return Money._(
      roundedMulDiv(minorUnits, part.milli, whole.milli),
      currencyCode,
      decimalPlaces,
    );
  }

  /// Net amount when this amount is a tax-inclusive gross at [basisPoints].
  Money netOfGross(int basisPoints) {
    _requireBasisPoints(basisPoints);
    return Money._(
      roundedMulDiv(minorUnits, 10000, 10000 + basisPoints),
      currencyCode,
      decimalPlaces,
    );
  }

  /// Tax portion when this amount is a tax-inclusive gross at [basisPoints].
  ///
  /// Always `this - netOfGross(basisPoints)` so net + tax equals gross
  /// exactly.
  Money taxPortionOfGross(int basisPoints) => this - netOfGross(basisPoints);

  /// Whether the amount is exactly zero.
  bool get isZero => minorUnits == 0;

  /// Whether the amount is below zero.
  bool get isNegative => minorUnits < 0;

  /// Whether the amount is above zero.
  bool get isPositive => minorUnits > 0;

  /// Plain decimal text with exactly [decimalPlaces] digits, e.g.
  /// `1234.50`. Locale-aware formatting lives in `MoneyFormatter`.
  String toPlainString() =>
      formatScaledDecimal(minorUnits, scale: decimalPlaces);

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currencyCode == currencyCode &&
      other.decimalPlaces == decimalPlaces;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode, decimalPlaces);

  @override
  String toString() => '$currencyCode ${toPlainString()}';

  void _requireSameCurrency(Money other) {
    if (other.currencyCode != currencyCode ||
        other.decimalPlaces != decimalPlaces) {
      throw CurrencyMismatchException(
        'Cannot combine $currencyCode/$decimalPlaces with '
        '${other.currencyCode}/${other.decimalPlaces}.',
      );
    }
  }

  static void _requireBasisPoints(int basisPoints) {
    if (basisPoints < 0) {
      throw ArgumentError.value(
        basisPoints,
        'basisPoints',
        'must not be negative',
      );
    }
  }

  static void _validate(String currencyCode, int decimalPlaces) {
    if (!_currencyPattern.hasMatch(currencyCode)) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'must be a 3-letter uppercase currency code',
      );
    }
    if (decimalPlaces < 0 || decimalPlaces > 4) {
      throw ArgumentError.value(
        decimalPlaces,
        'decimalPlaces',
        'must be between 0 and 4',
      );
    }
  }
}
