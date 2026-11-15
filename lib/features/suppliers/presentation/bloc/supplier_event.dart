import 'package:equatable/equatable.dart';

/// Events of the supplier list.
sealed class SupplierEvent extends Equatable {
  const SupplierEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load.
final class SuppliersStarted extends SupplierEvent {
  /// Creates the event.
  const SuppliersStarted();
}

/// Reload with the current filter.
final class SuppliersRefreshed extends SupplierEvent {
  /// Creates the event.
  const SuppliersRefreshed();
}

/// Search text changed.
final class SuppliersSearchChanged extends SupplierEvent {
  /// Creates the event.
  const SuppliersSearchChanged(this.query);

  /// New search text.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// "Show archived" toggled.
final class SuppliersArchivedFilterChanged extends SupplierEvent {
  /// Creates the event.
  const SuppliersArchivedFilterChanged({required this.includeArchived});

  /// Whether archived suppliers are shown.
  final bool includeArchived;

  @override
  List<Object?> get props => [includeArchived];
}

/// Archive or restore a supplier from the list.
final class SupplierArchiveToggled extends SupplierEvent {
  /// Creates the event.
  const SupplierArchiveToggled(this.supplierId, {required this.archive});

  /// Supplier id.
  final String supplierId;

  /// `true` to archive, `false` to restore.
  final bool archive;

  @override
  List<Object?> get props => [supplierId, archive];
}
