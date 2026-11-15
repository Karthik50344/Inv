import 'package:equatable/equatable.dart';

/// Criteria for listing products.
final class ProductFilter extends Equatable {
  /// Creates a filter.
  const ProductFilter({
    this.query = '',
    this.categoryId,
    this.includeArchived = false,
  });

  /// Matches name, SKU or barcode (contains, case-insensitive).
  final String query;

  /// Restrict to one category.
  final String? categoryId;

  /// Include archived products.
  final bool includeArchived;

  /// Copy with changes; pass [clearCategory] to remove the category filter.
  ProductFilter copyWith({
    String? query,
    String? categoryId,
    bool clearCategory = false,
    bool? includeArchived,
  }) => ProductFilter(
    query: query ?? this.query,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    includeArchived: includeArchived ?? this.includeArchived,
  );

  @override
  List<Object?> get props => [query, categoryId, includeArchived];
}
