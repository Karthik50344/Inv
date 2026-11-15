import 'package:equatable/equatable.dart';
import 'package:inventrix/core/utils/rounding.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/inventory/domain/entities/inventory_valuation.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/services/profit_calculator.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Everything the dashboard shows for one period.
///
/// The period figures (sales, purchases, expenses, profit, cash) cover
/// [range]. Inventory value, stock alerts and outstanding balances are
/// "as of now" and do not depend on the period.
final class DashboardSnapshot extends Equatable {
  /// Creates a snapshot.
  const DashboardSnapshot({
    required this.range,
    required this.generatedAt,
    required this.sales,
    required this.purchases,
    required this.expenses,
    required this.profit,
    required this.cash,
    required this.inventory,
    required this.receivable,
    required this.payable,
    required this.recentSales,
    required this.recentPurchases,
    required this.chart,
    required this.trendChart,
    required this.topProducts,
  });

  /// The period of the period figures.
  final DateRange range;

  /// When the data was read.
  final DateTime generatedAt;

  /// Sales and returns in the period.
  final DocumentFigures sales;

  /// Purchases and returns in the period.
  final DocumentFigures purchases;

  /// Posted expenses in the period.
  final ExpenseReport expenses;

  /// Gross profit and operating result estimates.
  final ProfitFigures profit;

  /// Cash received and paid in the period.
  final CashFigures cash;

  /// Inventory value and stock alert counts (as of now).
  final InventoryValuation inventory;

  /// What customers owe (positive balances), as of now.
  final Money receivable;

  /// What is owed to suppliers (positive balances), as of now.
  final Money payable;

  /// Newest posted sales invoices.
  final List<DocumentRow> recentSales;

  /// Newest posted purchase invoices.
  final List<DocumentRow> recentPurchases;

  /// Sales against purchases over the period.
  final ReportChart chart;

  /// Running total of net sales over the period.
  final ReportChart trendChart;

  /// The best-selling products of the period by net revenue (at most five;
  /// products with no net revenue are left out).
  final List<ProductFigures> topProducts;

  /// Average invoice value excluding tax (before returns); `null` without
  /// invoices.
  Money? get averageSale => sales.count == 0
      ? null
      : Money.fromMinor(
          roundedMulDiv(sales.net.minorUnits, 1, sales.count),
          currencyCode: sales.net.currencyCode,
          decimalPlaces: sales.net.decimalPlaces,
        );

  /// Sales tax collected minus tax on returns.
  Money get taxCollected => sales.tax - sales.returnsTax;

  /// Active products that are neither low nor out of stock.
  int get healthyStockCount {
    final healthy = inventory.productsInStock - inventory.lowStockCount;
    return healthy < 0 ? 0 : healthy;
  }

  /// Whether nothing at all has been recorded yet.
  bool get isBlank =>
      sales.isEmpty &&
      purchases.isEmpty &&
      expenses.isEmpty &&
      cash.entryCount == 0 &&
      inventory.totalValue.isZero &&
      inventory.productsInStock == 0 &&
      recentSales.isEmpty &&
      recentPurchases.isEmpty &&
      receivable.isZero &&
      payable.isZero;

  @override
  List<Object?> get props => [
    range,
    generatedAt,
    sales,
    purchases,
    expenses,
    profit,
    cash,
    inventory,
    receivable,
    payable,
    recentSales,
    recentPurchases,
    chart,
    trendChart,
    topProducts,
  ];
}
