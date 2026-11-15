import 'package:equatable/equatable.dart';
import 'package:inventrix/features/inventory/domain/entities/inventory_valuation.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_item.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the stock list.
final class InventoryState extends Equatable {
  /// Creates a state.
  const InventoryState({
    this.status = ViewStatus.initial,
    this.items = const [],
    this.filter = const StockFilter(),
    this.valuation,
    this.units = const {},
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded stock items.
  final List<StockItem> items;

  /// Active filter.
  final StockFilter filter;

  /// Totals across all products (independent of the filter).
  final InventoryValuation? valuation;

  /// Units by id for symbol lookup.
  final Map<String, UnitOfMeasure> units;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  InventoryState copyWith({
    ViewStatus? status,
    List<StockItem>? items,
    StockFilter? filter,
    InventoryValuation? valuation,
    Map<String, UnitOfMeasure>? units,
    String? message,
  }) => InventoryState(
    status: status ?? this.status,
    items: items ?? this.items,
    filter: filter ?? this.filter,
    valuation: valuation ?? this.valuation,
    units: units ?? this.units,
    message: message,
  );

  @override
  List<Object?> get props => [status, items, filter, valuation, units, message];
}
