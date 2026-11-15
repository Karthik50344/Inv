import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/dashboard/domain/entities/dashboard_snapshot.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/payments/domain/entities/party_balance.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/usecases/get_party_balance.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_repository.dart';
import 'package:inventrix/features/reports/domain/services/time_buckets.dart';
import 'package:inventrix/features/reports/domain/usecases/get_profit_figures.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Reads every figure of the dashboard from the local database.
final class GetDashboard {
  /// Creates the use case.
  const GetDashboard({
    required ReportRepository reports,
    required ExpenseRepository expenses,
    required InventoryRepository inventory,
    required GetPartyBalance balances,
    required GetProfitFigures profit,
    required SettingsRepository settings,
    required Clock clock,
  }) : _reports = reports,
       _expenses = expenses,
       _inventory = inventory,
       _balances = balances,
       _profit = profit,
       _settings = settings,
       _clock = clock;

  /// How many recent documents the dashboard lists.
  static const int recentCount = 5;

  /// How many best-selling products the dashboard lists.
  static const int topProductCount = 5;

  final ReportRepository _reports;
  final ExpenseRepository _expenses;
  final InventoryRepository _inventory;
  final GetPartyBalance _balances;
  final GetProfitFigures _profit;
  final SettingsRepository _settings;
  final Clock _clock;

  /// Loads the dashboard for [range].
  Future<Result<DashboardSnapshot>> call(DateRange range) async {
    try {
      final currency = (await _settings.getCurrencyConfig()).getOrThrow();
      final filter = ReportFilter(range: range);
      final sales = (await _reports.salesFigures(filter)).getOrThrow();
      final purchases = (await _reports.purchaseFigures(filter)).getOrThrow();
      final expenses = (await _expenses.report(
        ExpenseReportFilter(from: range.from, to: range.to),
      )).getOrThrow();
      final profit = (await _profit(filter)).getOrThrow();
      final cash = (await _reports.cashFigures(filter)).getOrThrow();
      final inventory = (await _inventory.valuation()).getOrThrow();
      final customers = (await _balances.outstanding(PartyType.customer))
          .getOrThrow();
      final suppliers = (await _balances.outstanding(PartyType.supplier))
          .getOrThrow();
      final recentSales = (await _reports.recentSales(recentCount))
          .getOrThrow();
      final recentPurchases = (await _reports.recentPurchases(recentCount))
          .getOrThrow();
      final salesSeries = (await _reports.salesByDay(filter)).getOrThrow();
      final purchaseSeries = (await _reports.purchasesByDay(filter))
          .getOrThrow();

      final products = (await _reports.productFigures(filter)).getOrThrow();
      final top = [
        for (final p in products)
          if (p.netRevenue.isPositive) p,
      ].take(topProductCount).toList();
      final buckets = TimeBuckets.build(range);
      final netSalesByBucket = TimeBuckets.net(buckets, salesSeries);
      return Result.success(
        DashboardSnapshot(
          range: range,
          generatedAt: _clock.now(),
          sales: sales,
          purchases: purchases,
          expenses: expenses,
          profit: profit,
          cash: cash,
          inventory: inventory,
          receivable: _owed(customers, currency.zero()),
          payable: _owed(suppliers, currency.zero()),
          recentSales: recentSales,
          recentPurchases: recentPurchases,
          chart: ReportChart(
            title: 'Sales and purchases (excl. tax)',
            labels: [for (final b in buckets) b.label],
            series: [
              ChartSeries('Sales', TimeBuckets.net(buckets, salesSeries)),
              ChartSeries(
                'Purchases',
                TimeBuckets.net(buckets, purchaseSeries),
              ),
            ],
            currencyCode: currency.currencyCode,
            decimalPlaces: currency.decimalPlaces,
          ),
          trendChart: ReportChart(
            title: 'Net sales, running total (excl. tax)',
            labels: [for (final b in buckets) b.label],
            series: [
              ChartSeries(
                'Net sales',
                TimeBuckets.cumulative(netSalesByBucket),
              ),
            ],
            currencyCode: currency.currencyCode,
            decimalPlaces: currency.decimalPlaces,
          ),
          topProducts: top,
        ),
      );
    } on FailureException catch (error) {
      return Result.failure(error.failure);
    }
  }

  /// Sum of the positive balances: what is actually owed. Credit balances
  /// are not netted against other parties' debts.
  static Money _owed(List<PartyBalance> balances, Money zero) {
    var total = zero;
    for (final b in balances) {
      if (b.balance.isPositive) {
        total += b.balance;
      }
    }
    return total;
  }
}
