import 'package:equatable/equatable.dart';

/// Events of the customer list.
sealed class CustomerEvent extends Equatable {
  const CustomerEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load.
final class CustomersStarted extends CustomerEvent {
  /// Creates the event.
  const CustomersStarted();
}

/// Reload with the current filter.
final class CustomersRefreshed extends CustomerEvent {
  /// Creates the event.
  const CustomersRefreshed();
}

/// Search text changed.
final class CustomersSearchChanged extends CustomerEvent {
  /// Creates the event.
  const CustomersSearchChanged(this.query);

  /// New search text.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// "Show archived" toggled.
final class CustomersArchivedFilterChanged extends CustomerEvent {
  /// Creates the event.
  const CustomersArchivedFilterChanged({required this.includeArchived});

  /// Whether archived customers are shown.
  final bool includeArchived;

  @override
  List<Object?> get props => [includeArchived];
}

/// Archive or restore a customer from the list.
final class CustomerArchiveToggled extends CustomerEvent {
  /// Creates the event.
  const CustomerArchiveToggled(this.customerId, {required this.archive});

  /// Customer id.
  final String customerId;

  /// `true` to archive, `false` to restore.
  final bool archive;

  @override
  List<Object?> get props => [customerId, archive];
}
