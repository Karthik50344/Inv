/// The reports offered by the app.
enum ReportKind {
  /// Posted sales, returns and net sales.
  sales(
    'Sales report',
    'Invoices, returns and net sales for a period.',
    supportsCustomer: true,
  ),

  /// Posted purchases, returns and net purchases.
  purchases(
    'Purchase report',
    'Supplier invoices, returns and net purchases for a period.',
    supportsSupplier: true,
  ),

  /// Stock on hand with its value.
  inventory(
    'Inventory report',
    'Quantity and value of the stock on hand right now.',
    usesDateRange: false,
  ),

  /// Every stock ledger entry in a period.
  stockMovements(
    'Stock movement report',
    'The stock ledger: every increase and decrease in a period.',
    supportsProduct: true,
  ),

  /// Products at or below their reorder level.
  lowStock(
    'Low-stock report',
    'Products that are low or out of stock right now.',
    usesDateRange: false,
  ),

  /// Units sold, revenue and profit per product.
  productPerformance(
    'Product performance',
    'Units sold, revenue, cost and gross profit per product.',
    supportsProduct: true,
  ),

  /// Customers who owe money.
  customerOutstanding(
    'Customer outstanding',
    'What each customer owes you right now.',
    usesDateRange: false,
  ),

  /// Suppliers who are owed money.
  supplierOutstanding(
    'Supplier outstanding',
    'What you owe each supplier right now.',
    usesDateRange: false,
  ),

  /// Cash received and paid.
  payments(
    'Payment report',
    'Cash received and paid out, by payment method.',
    supportsCustomer: true,
    supportsSupplier: true,
  ),

  /// Posted expenses by category.
  expenses('Expense report', 'Posted expenses by category for a period.'),

  /// Net sales, cost of goods sold, expenses and operating result.
  profitability(
    'Profitability report',
    'Gross profit and operating result estimates for a period.',
  );

  const ReportKind(
    this.title,
    this.description, {
    this.usesDateRange = true,
    this.supportsProduct = false,
    this.supportsCustomer = false,
    this.supportsSupplier = false,
  });

  /// Title for lists and app bars.
  final String title;

  /// One-line description for the report list.
  final String description;

  /// Whether the report is about a period (otherwise "as of now").
  final bool usesDateRange;

  /// Whether the product filter applies.
  final bool supportsProduct;

  /// Whether the customer filter applies.
  final bool supportsCustomer;

  /// Whether the supplier filter applies.
  final bool supportsSupplier;

  /// Name used in routes and file names.
  String get slug => switch (this) {
    ReportKind.stockMovements => 'stock-movements',
    ReportKind.lowStock => 'low-stock',
    ReportKind.productPerformance => 'product-performance',
    ReportKind.customerOutstanding => 'customer-outstanding',
    ReportKind.supplierOutstanding => 'supplier-outstanding',
    _ => name,
  };

  /// Parses a [slug]; `null` if unknown.
  static ReportKind? fromSlug(String slug) {
    for (final kind in values) {
      if (kind.slug == slug) {
        return kind;
      }
    }
    return null;
  }
}
