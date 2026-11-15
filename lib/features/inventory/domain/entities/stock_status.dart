/// Stock health of a product.
enum StockStatus {
  /// Stock is above the reorder level (or no reorder level is set).
  ok,

  /// Stock is at or below the reorder level but not zero.
  low,

  /// No stock.
  out,
}

/// Status filter for stock lists.
enum StockStatusFilter {
  all,
  low,
  out,
  lowOrOut;

  /// Whether [status] passes this filter.
  bool matches(StockStatus status) => switch (this) {
    StockStatusFilter.all => true,
    StockStatusFilter.low => status == StockStatus.low,
    StockStatusFilter.out => status == StockStatus.out,
    StockStatusFilter.lowOrOut => status != StockStatus.ok,
  };
}
