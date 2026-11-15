import 'package:inventrix/core/utils/decimal_text.dart';
import 'package:inventrix/core/utils/rounding.dart';

/// Immutable quantity stored as an integer number of milli-units
/// (scale 10^3), so 1.5 kg is `Quantity.fromMilli(1500)`.
///
/// Quantities may be negative (e.g. signed stock movements); rules such as
/// "stock cannot go negative" are enforced by domain services, not here.
final class Quantity implements Comparable<Quantity> {
  /// Creates a quantity from raw milli-units.
  const Quantity.fromMilli(this.milli);

  /// Creates a quantity from whole units (`fromUnits(3)` is 3.000).
  factory Quantity.fromUnits(int units) =>
      Quantity.fromMilli(roundedMulDiv(units, factor, 1));

  /// Number of decimal digits stored.
  static const int scale = 3;

  /// Milli-units per whole unit.
  static const int factor = 1000;

  /// The zero quantity.
  static const Quantity zero = Quantity.fromMilli(0);

  /// Parses plain decimal text such as `12`, `12.5` or `-0.001`.
  ///
  /// [maxDecimalPlaces] (0–3) restricts input to a unit's precision.
  /// Returns `null` for malformed or over-precise input.
  static Quantity? tryParse(String input, {int maxDecimalPlaces = scale}) {
    final milli = parseScaledDecimal(
      input,
      scale: scale,
      maxFractionDigits: maxDecimalPlaces,
    );
    return milli == null ? null : Quantity.fromMilli(milli);
  }

  /// Raw value in milli-units.
  final int milli;

  /// Sum of two quantities (overflow-checked).
  Quantity operator +(Quantity other) =>
      Quantity.fromMilli(checkedAdd(milli, other.milli));

  /// Difference of two quantities (overflow-checked).
  Quantity operator -(Quantity other) =>
      Quantity.fromMilli(checkedSub(milli, other.milli));

  /// Whether this is smaller than [other].
  bool operator <(Quantity other) => milli < other.milli;

  /// Whether this is smaller than or equal to [other].
  bool operator <=(Quantity other) => milli <= other.milli;

  /// Whether this is greater than [other].
  bool operator >(Quantity other) => milli > other.milli;

  /// Whether this is greater than or equal to [other].
  bool operator >=(Quantity other) => milli >= other.milli;

  /// The quantity with the opposite sign.
  Quantity negate() => Quantity.fromMilli(checkedSub(0, milli));

  /// Absolute value.
  Quantity abs() => isNegative ? negate() : this;

  /// Whether the quantity is exactly zero.
  bool get isZero => milli == 0;

  /// Whether the quantity is below zero.
  bool get isNegative => milli < 0;

  /// Whether the quantity is above zero.
  bool get isPositive => milli > 0;

  /// Whether the value can be expressed with at most [places] decimals.
  bool fitsDecimalPlaces(int places) =>
      places >= scale || milli % pow10(scale - places) == 0;

  /// Plain decimal text without trailing zeros (`1500` -> `1.5`).
  String toDecimalString() {
    final full = formatScaledDecimal(milli, scale: scale);
    if (!full.contains('.')) {
      return full;
    }
    final trimmed = full.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.endsWith('.')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  /// Plain decimal text with exactly [decimalPlaces] digits (rounded half
  /// away from zero when fewer than 3).
  String toFixedString(int decimalPlaces) =>
      formatScaledDecimal(milli, scale: scale, fractionDigits: decimalPlaces);

  @override
  int compareTo(Quantity other) => milli.compareTo(other.milli);

  @override
  bool operator ==(Object other) => other is Quantity && other.milli == milli;

  @override
  int get hashCode => milli.hashCode;

  @override
  String toString() => 'Quantity(${toDecimalString()})';
}
