import 'package:equatable/equatable.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_position.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Outcome of applying a stock-in or stock-out to a [StockPosition].
final class StockPosting extends Equatable {
  /// Creates a posting.
  const StockPosting({
    required this.position,
    required this.quantityDelta,
    required this.costDelta,
  });

  /// The new position.
  final StockPosition position;

  /// Signed quantity change to record in the ledger.
  final Quantity quantityDelta;

  /// Signed value change to record in the ledger.
  final Money costDelta;

  @override
  List<Object?> get props => [position, quantityDelta, costDelta];
}

/// Weighted-average-cost arithmetic (see ADR-003).
///
/// The position tracks total value rather than a stored unit cost, so
/// rounding never drifts: a stock-out takes a rounded proportion of the
/// value, and removing the last unit takes *all* remaining value. Over any
/// complete cycle (stock in ... stock fully out) the sum of costs of goods
/// sold equals the sum of costs received exactly.
abstract final class StockCalculator {
  /// Adds [quantity] received at a total [cost] to [position].
  ///
  /// Throws [ArgumentError] if [quantity] is not positive or [cost] is
  /// negative.
  static StockPosting stockIn(
    StockPosition position,
    Quantity quantity,
    Money cost,
  ) {
    _requirePositive(quantity);
    if (cost.isNegative) {
      throw ArgumentError.value(cost, 'cost', 'must not be negative');
    }
    return StockPosting(
      position: StockPosition(
        quantity: position.quantity + quantity,
        value: position.value + cost,
      ),
      quantityDelta: quantity,
      costDelta: cost,
    );
  }

  /// Removes [quantity] from [position] at the current average cost.
  ///
  /// Fails with [InsufficientStockFailure] when [quantity] exceeds the stock
  /// on hand; stock can never go negative.
  static Result<StockPosting> stockOut({
    required String productId,
    required StockPosition position,
    required Quantity quantity,
  }) {
    _requirePositive(quantity);
    if (quantity > position.quantity) {
      return Result.failure(
        InsufficientStockFailure(
          'Only ${position.quantity.toDecimalString()} in stock, but '
          '${quantity.toDecimalString()} requested.',
          productId: productId,
          requestedMilli: quantity.milli,
          availableMilli: position.quantity.milli,
        ),
      );
    }
    final cost = costAtAverage(position, quantity);
    return Result.success(
      StockPosting(
        position: StockPosition(
          quantity: position.quantity - quantity,
          value: position.value - cost,
        ),
        quantityDelta: quantity.negate(),
        costDelta: cost.negate(),
      ),
    );
  }

  /// Removes [quantity] that was previously received at [originalCost]
  /// (voiding a purchase).
  ///
  /// Taking back stock at its original cost restores the average cost the
  /// stock had before the receipt. The cost removed is capped at the value
  /// on hand (later sales may have lowered it), and removing the whole
  /// quantity on hand takes the whole value, so the position invariants
  /// (no negative value, zero quantity implies zero value) always hold.
  ///
  /// Fails with [InsufficientStockFailure] when part of the received stock
  /// has already left (for example it was sold): stock never goes negative.
  static Result<StockPosting> removeReceived({
    required String productId,
    required StockPosition position,
    required Quantity quantity,
    required Money originalCost,
  }) {
    _requirePositive(quantity);
    if (originalCost.isNegative) {
      throw ArgumentError.value(
        originalCost,
        'originalCost',
        'must not be negative',
      );
    }
    if (quantity > position.quantity) {
      return Result.failure(
        InsufficientStockFailure(
          'Only ${position.quantity.toDecimalString()} in stock, but '
          '${quantity.toDecimalString()} would have to be removed.',
          productId: productId,
          requestedMilli: quantity.milli,
          availableMilli: position.quantity.milli,
        ),
      );
    }
    final Money cost;
    if (quantity == position.quantity) {
      cost = position.value;
    } else {
      cost = originalCost > position.value ? position.value : originalCost;
    }
    return Result.success(
      StockPosting(
        position: StockPosition(
          quantity: position.quantity - quantity,
          value: position.value - cost,
        ),
        quantityDelta: quantity.negate(),
        costDelta: cost.negate(),
      ),
    );
  }

  /// Value of [quantity] at the position's average cost. Taking the whole
  /// quantity returns the whole value exactly.
  ///
  /// Throws [ArgumentError] unless `0 < quantity <= position.quantity`.
  static Money costAtAverage(StockPosition position, Quantity quantity) {
    _requirePositive(quantity);
    if (quantity > position.quantity) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'exceeds the quantity on hand',
      );
    }
    return quantity == position.quantity
        ? position.value
        : position.value.prorate(quantity, position.quantity);
  }

  static void _requirePositive(Quantity quantity) {
    if (!quantity.isPositive) {
      throw ArgumentError.value(quantity, 'quantity', 'must be positive');
    }
  }
}
