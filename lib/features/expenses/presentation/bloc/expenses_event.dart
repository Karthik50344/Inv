import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Events of the expense list.
sealed class ExpensesEvent extends Equatable {
  const ExpensesEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load.
final class ExpensesStarted extends ExpensesEvent {
  /// Creates the event.
  const ExpensesStarted();
}

/// Reload with the current filter.
final class ExpensesRefreshed extends ExpensesEvent {
  /// Creates the event.
  const ExpensesRefreshed();
}

/// Search text changed.
final class ExpensesSearchChanged extends ExpensesEvent {
  /// Creates the event.
  const ExpensesSearchChanged(this.query);

  /// New search text.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Status filter changed; `null` shows every status.
final class ExpensesStatusChanged extends ExpensesEvent {
  /// Creates the event.
  const ExpensesStatusChanged(this.status);

  /// Selected status.
  final DocumentStatus? status;

  @override
  List<Object?> get props => [status];
}

/// Category filter changed; `null` shows every category.
final class ExpensesCategoryChanged extends ExpensesEvent {
  /// Creates the event.
  const ExpensesCategoryChanged(this.categoryId);

  /// Selected category id.
  final String? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

/// Date range changed; both `null` removes the range.
final class ExpensesRangeChanged extends ExpensesEvent {
  /// Creates the event.
  const ExpensesRangeChanged({this.from, this.to});

  /// First day (date only).
  final DateTime? from;

  /// Last day (date only).
  final DateTime? to;

  @override
  List<Object?> get props => [from, to];
}
