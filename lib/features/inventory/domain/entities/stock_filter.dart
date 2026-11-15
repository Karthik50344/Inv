import 'package:equatable/equatable.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';

/// Criteria for listing stock.
final class StockFilter extends Equatable {
  /// Creates a filter.
  const StockFilter({
    this.query = '',
    this.categoryId,
    this.status = StockStatusFilter.all,
    this.includeArchived = false,
  });

  /// Matches name, SKU or barcode.
  final String query;

  /// Restrict to one category.
  final String? categoryId;

  /// Stock health filter.
  final StockStatusFilter status;

  /// Include archived products.
  final bool includeArchived;

  /// Copy with changes; use [clearCategory] to drop the category filter.
  StockFilter copyWith({
    String? query,
    String? categoryId,
    bool clearCategory = false,
    StockStatusFilter? status,
    bool? includeArchived,
  }) => StockFilter(
    query: query ?? this.query,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    status: status ?? this.status,
    includeArchived: includeArchived ?? this.includeArchived,
  );

  @override
  List<Object?> get props => [query, categoryId, status, includeArchived];
}
