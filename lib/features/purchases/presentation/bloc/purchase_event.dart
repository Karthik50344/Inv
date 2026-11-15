import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Events of the purchase list.
sealed class PurchaseEvent extends Equatable {
  const PurchaseEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load.
final class PurchasesStarted extends PurchaseEvent {
  /// Creates the event.
  const PurchasesStarted();
}

/// Reload with the current filter.
final class PurchasesRefreshed extends PurchaseEvent {
  /// Creates the event.
  const PurchasesRefreshed();
}

/// Search text changed.
final class PurchasesSearchChanged extends PurchaseEvent {
  /// Creates the event.
  const PurchasesSearchChanged(this.query);

  /// New search text.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Status filter changed; `null` shows every status.
final class PurchasesStatusChanged extends PurchaseEvent {
  /// Creates the event.
  const PurchasesStatusChanged(this.status);

  /// Selected status.
  final DocumentStatus? status;

  @override
  List<Object?> get props => [status];
}

/// The "require approval" setting was toggled.
final class PurchasesApprovalToggled extends PurchaseEvent {
  /// Creates the event.
  const PurchasesApprovalToggled({required this.required});

  /// New value.
  final bool required;

  @override
  List<Object?> get props => [required];
}
