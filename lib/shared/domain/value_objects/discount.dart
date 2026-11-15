import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// How a [Discount] is expressed.
enum DiscountKind {
  none('none'),
  percent('percent'),
  amount('amount');

  const DiscountKind(this.dbName);

  /// Value stored in the database.
  final String dbName;

  /// Parses a stored value.
  static DiscountKind fromDbName(String value) =>
      DiscountKind.values.firstWhere(
        (kind) => kind.dbName == value,
        orElse: () =>
            throw ArgumentError.value(value, 'value', 'Unknown discount kind'),
      );
}

/// An immutable line discount: nothing, a percentage (basis points) or a
/// fixed amount.
final class Discount extends Equatable {
  /// No discount.
  const Discount.none()
    : kind = DiscountKind.none,
      basisPoints = 0,
      _amount = null;

  /// A percentage discount of [basisPoints] (1% = 100), from 0 to 10000.
  factory Discount.percent(int basisPoints) {
    if (basisPoints < 0 || basisPoints > 10000) {
      throw ArgumentError.value(
        basisPoints,
        'basisPoints',
        'must be between 0 and 10000',
      );
    }
    return Discount._(DiscountKind.percent, basisPoints, null);
  }

  /// A fixed-amount discount; [amount] must not be negative.
  factory Discount.amount(Money amount) {
    if (amount.isNegative) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    return Discount._(DiscountKind.amount, 0, amount);
  }

  const Discount._(this.kind, this.basisPoints, this._amount);

  /// Rebuilds a discount from its stored form ([kind] and [value] in basis
  /// points or minor units).
  factory Discount.fromStored(
    DiscountKind kind,
    int value, {
    required Money Function(int minor) money,
  }) => switch (kind) {
    DiscountKind.none => const Discount.none(),
    DiscountKind.percent => Discount.percent(value),
    DiscountKind.amount => Discount.amount(money(value)),
  };

  /// The kind of discount.
  final DiscountKind kind;

  /// Percentage in basis points (only meaningful for [DiscountKind.percent]).
  final int basisPoints;

  final Money? _amount;

  /// Fixed amount (only for [DiscountKind.amount]).
  Money? get amount => _amount;

  /// Whether this is no discount at all.
  bool get isNone => kind == DiscountKind.none;

  /// The value to store next to [kind]: basis points for a percentage, minor
  /// units for an amount, 0 for none.
  int get storedValue => switch (kind) {
    DiscountKind.none => 0,
    DiscountKind.percent => basisPoints,
    DiscountKind.amount => _amount!.minorUnits,
  };

  /// The discount in money terms for a [gross] amount. A percentage is
  /// rounded once, half away from zero. Callers must check that a fixed
  /// amount does not exceed [gross].
  Money appliedTo(Money gross) => switch (kind) {
    DiscountKind.none => gross.multiplyByInt(0),
    DiscountKind.percent => gross.applyBasisPoints(basisPoints),
    DiscountKind.amount => _amount!,
  };

  @override
  List<Object?> get props => [kind, basisPoints, _amount];
}
