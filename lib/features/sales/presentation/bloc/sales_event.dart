import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Events of the sale list.
sealed class SalesEvent extends Equatable {
  const SalesEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load.
final class SalesStarted extends SalesEvent {
  /// Creates the event.
  const SalesStarted();
}

/// Reload with the current filter.
final class SalesRefreshed extends SalesEvent {
  /// Creates the event.
  const SalesRefreshed();
}

/// Search text changed.
final class SalesSearchChanged extends SalesEvent {
  /// Creates the event.
  const SalesSearchChanged(this.query);

  /// New search text.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Status filter changed; `null` shows every status.
final class SalesStatusChanged extends SalesEvent {
  /// Creates the event.
  const SalesStatusChanged(this.status);

  /// Selected status.
  final DocumentStatus? status;

  @override
  List<Object?> get props => [status];
}

/// The "require approval" setting was toggled.
final class SalesApprovalToggled extends SalesEvent {
  /// Creates the event.
  const SalesApprovalToggled({required this.required});

  /// New value.
  final bool required;

  @override
  List<Object?> get props => [required];
}
