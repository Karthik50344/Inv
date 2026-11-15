import 'package:equatable/equatable.dart';

/// Events of the product list.
sealed class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load.
final class ProductsStarted extends ProductEvent {
  /// Creates the event.
  const ProductsStarted();
}

/// Reload with the current filter.
final class ProductsRefreshed extends ProductEvent {
  /// Creates the event.
  const ProductsRefreshed();
}

/// Search text changed.
final class ProductsSearchChanged extends ProductEvent {
  /// Creates the event.
  const ProductsSearchChanged(this.query);

  /// New search text.
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Category filter changed (`null` clears it).
final class ProductsCategoryFilterChanged extends ProductEvent {
  /// Creates the event.
  const ProductsCategoryFilterChanged(this.categoryId);

  /// Selected category id.
  final String? categoryId;

  @override
  List<Object?> get props => [categoryId];
}

/// "Show archived" toggled.
final class ProductsArchivedFilterChanged extends ProductEvent {
  /// Creates the event.
  const ProductsArchivedFilterChanged({required this.includeArchived});

  /// Whether archived products are shown.
  final bool includeArchived;

  @override
  List<Object?> get props => [includeArchived];
}

/// Archive or restore a product from the list.
final class ProductArchiveToggled extends ProductEvent {
  /// Creates the event.
  const ProductArchiveToggled(this.productId, {required this.archive});

  /// Product id.
  final String productId;

  /// `true` to archive, `false` to restore.
  final bool archive;

  @override
  List<Object?> get props => [productId, archive];
}
