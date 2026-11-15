import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Read-only aggregate queries behind the dashboard and the reports.
///
/// Rules shared by every method:
/// - only **posted** documents count (drafts, cancelled and voided ones do
///   not);
/// - a document belongs to the period of its **document date**, a return to
///   the period of its **return date**, a payment to its **payment date**;
/// - only the configured currency is added up; other currencies are counted
///   in the `otherCurrencyCount` of the result;
/// - nothing is written, and nothing is cached: the figures always come
///   from the stored records.
abstract interface class ReportRepository {
  /// Sales and sales returns in [ReportFilter.range]; honours
  /// [ReportFilter.customerId].
  Future<Result<DocumentFigures>> salesFigures(ReportFilter filter);

  /// Purchases and purchase returns; honours [ReportFilter.supplierId].
  Future<Result<DocumentFigures>> purchaseFigures(ReportFilter filter);

  /// The newest posted sales invoices in the range, at most [limit].
  Future<Result<List<DocumentRow>>> salesRows(
    ReportFilter filter, {
    required int limit,
  });

  /// The newest posted purchase invoices in the range, at most [limit].
  Future<Result<List<DocumentRow>>> purchaseRows(
    ReportFilter filter, {
    required int limit,
  });

  /// Net sales and returns per day (for charts).
  Future<Result<DailySeries>> salesByDay(ReportFilter filter);

  /// Net purchases and returns per day (for charts).
  Future<Result<DailySeries>> purchasesByDay(ReportFilter filter);

  /// Cost of the goods sold in [range], read from the stock ledger: the
  /// cost of every posted sale line minus the cost of goods that went back
  /// into stock through sales returns in the same range.
  Future<Result<Money>> costOfGoodsSold(DateRange range);

  /// Sales per product; honours [ReportFilter.productId]. Largest net
  /// revenue first.
  Future<Result<List<ProductFigures>>> productFigures(ReportFilter filter);

  /// Cash received and paid; honours the customer and supplier filters.
  Future<Result<CashFigures>> cashFigures(ReportFilter filter);

  /// Stock ledger entries in the range (newest first, at most [limit]),
  /// with totals over all entries; honours [ReportFilter.productId].
  Future<Result<MovementReportData>> stockMovements(
    ReportFilter filter, {
    required int limit,
  });

  /// The newest posted sales invoices, at most [limit].
  Future<Result<List<DocumentRow>>> recentSales(int limit);

  /// The newest posted purchase invoices, at most [limit].
  Future<Result<List<DocumentRow>>> recentPurchases(int limit);
}
