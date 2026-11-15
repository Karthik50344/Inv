import 'package:equatable/equatable.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// One immutable entry in the stock ledger.
final class StockMovement extends Equatable {
  /// Creates a movement.
  const StockMovement({
    required this.id,
    required this.productId,
    required this.type,
    required this.quantityDelta,
    required this.totalCost,
    required this.unitCost,
    required this.occurredAt,
    required this.createdAt,
    this.sourceType,
    this.sourceId,
    this.sourceLineId,
    this.reason,
  });

  /// Unique id.
  final String id;

  /// Product whose stock changed.
  final String productId;

  /// Kind of movement.
  final StockMovementType type;

  /// Signed quantity change (positive = stock in).
  final Quantity quantityDelta;

  /// Signed value change; same sign as [quantityDelta] (or zero).
  final Money totalCost;

  /// Cost per unit at the time (informational snapshot).
  final Money unitCost;

  /// Originating document type, when the movement comes from a document.
  final String? sourceType;

  /// Originating document id.
  final String? sourceId;

  /// Originating document line id.
  final String? sourceLineId;

  /// Reason (mandatory for adjustments).
  final String? reason;

  /// When the movement happened (UTC).
  final DateTime occurredAt;

  /// When it was recorded (UTC).
  final DateTime createdAt;

  /// Whether the movement increases stock.
  bool get isInbound => quantityDelta.isPositive;

  @override
  List<Object?> get props => [
    id,
    productId,
    type,
    quantityDelta,
    totalCost,
    unitCost,
    sourceType,
    sourceId,
    sourceLineId,
    reason,
    occurredAt,
    createdAt,
  ];
}
