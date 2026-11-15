import 'package:equatable/equatable.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';

/// Events of the stock list.
sealed class InventoryEvent extends Equatable {
  const InventoryEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load.
final class InventoryStarted extends InventoryEvent {
  /// Creates the event.
  const InventoryStarted();
}

/// Reload with the current filter.
final class InventoryRefreshed extends InventoryEvent {
  /// Creates the event.
  const InventoryRefreshed();
}

/// Search text changed.
final class InventorySearchChanged extends InventoryEvent {
  /// Creates the event.
  const InventorySearchChanged(this.query);

  /// New search text.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Stock status filter changed.
final class InventoryStatusFilterChanged extends InventoryEvent {
  /// Creates the event.
  const InventoryStatusFilterChanged(this.status);

  /// The selected filter.
  final StockStatusFilter status;

  @override
  List<Object?> get props => [status];
}
