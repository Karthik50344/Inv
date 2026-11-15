import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/usecases/get_party_balance.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/repositories/report_repository.dart';
import 'package:inventrix/features/reports/domain/services/finance_report_documents.dart';
import 'package:inventrix/features/reports/domain/services/profit_calculator.dart';
import 'package:inventrix/features/reports/domain/services/register_report_document.dart';
import 'package:inventrix/features/reports/domain/services/report_filter_options.dart';
import 'package:inventrix/features/reports/domain/services/stock_report_documents.dart';
import 'package:inventrix/features/reports/domain/usecases/get_profit_figures.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';

/// Builds any report as a [ReportDocument].
///
/// Reads only; nothing is written. The use case decides which records feed
/// which report; the arithmetic lives in [ProfitFigures] and the document
/// builders so it can be tested without a database.
final class BuildReport {
  /// Creates the use case.
  const BuildReport({
    required ReportRepository reports,
    required ExpenseRepository expenses,
    required GetProfitFigures profit,
    required InventoryRepository inventory,
    required UnitRepository units,
    required GetPartyBalance balances,
    required ReportFilterOptions options,
    required SettingsRepository settings,
    required Clock clock,
  }) : _reports = reports,
       _expenses = expenses,
       _profit = profit,
       _inventory = inventory,
       _units = units,
       _balances = balances,
       _options = options,
       _settings = settings,
       _clock = clock;

  /// Largest number of table rows read for one report. Longer lists are cut
  /// to the newest rows and the document says so.
  static const int rowLimit = 1000;

  final ReportRepository _reports;
  final ExpenseRepository _expenses;
  final GetProfitFigures _profit;
  final InventoryRepository _inventory;
  final UnitRepository _units;
  final GetPartyBalance _balances;
  final ReportFilterOptions _options;
  final SettingsRepository _settings;
  final Clock _clock;

  /// Builds the report of [kind] for [filter].
  Future<Result<ReportDocument>> call(
    ReportKind kind,
    ReportFilter filter,
  ) async {
    try {
      final currency = (await _settings.getCurrencyConfig()).getOrThrow();
      final zero = currency.zero();
      final now = _clock.now();
      final scope = await _scope(kind, filter);
      switch (kind) {
        case ReportKind.sales:
          final figures = (await _reports.salesFigures(filter)).getOrThrow();
          final rows = (await _reports.salesRows(
            filter,
            limit: rowLimit,
          )).getOrThrow();
          final series = (await _reports.salesByDay(filter)).getOrThrow();
          return Result.success(
            RegisterReportDocument.build(
              kind: kind,
              filter: filter,
              generatedAt: now,
              scope: scope,
              figures: figures,
              rows: rows,
              series: series,
            ),
          );
        case ReportKind.purchases:
          final figures = (await _reports.purchaseFigures(filter)).getOrThrow();
          final rows = (await _reports.purchaseRows(
            filter,
            limit: rowLimit,
          )).getOrThrow();
          final series = (await _reports.purchasesByDay(filter)).getOrThrow();
          return Result.success(
            RegisterReportDocument.build(
              kind: kind,
              filter: filter,
              generatedAt: now,
              scope: scope,
              figures: figures,
              rows: rows,
              series: series,
            ),
          );
        case ReportKind.inventory:
          final items = (await _inventory.listStock(
            const StockFilter(includeArchived: true),
          )).getOrThrow();
          return Result.success(
            StockReportDocuments.inventory(
              generatedAt: now,
              items: items,
              units: await _unitMap(),
              zero: zero,
            ),
          );
        case ReportKind.lowStock:
          final items = (await _inventory.listStock(
            const StockFilter(status: StockStatusFilter.lowOrOut),
          )).getOrThrow();
          return Result.success(
            StockReportDocuments.lowStock(
              generatedAt: now,
              items: items,
              units: await _unitMap(),
            ),
          );
        case ReportKind.stockMovements:
          final data = (await _reports.stockMovements(
            filter,
            limit: rowLimit,
          )).getOrThrow();
          return Result.success(
            StockReportDocuments.movements(
              filter: filter,
              generatedAt: now,
              scope: scope,
              data: data,
            ),
          );
        case ReportKind.productPerformance:
          final products = (await _reports.productFigures(filter)).getOrThrow();
          return Result.success(
            FinanceReportDocuments.productPerformance(
              filter: filter,
              generatedAt: now,
              scope: scope,
              products: products,
              zero: zero,
            ),
          );
        case ReportKind.customerOutstanding:
          final list = (await _balances.outstanding(PartyType.customer))
              .getOrThrow();
          return Result.success(
            FinanceReportDocuments.outstanding(
              type: PartyType.customer,
              generatedAt: now,
              balances: list,
              zero: zero,
            ),
          );
        case ReportKind.supplierOutstanding:
          final list = (await _balances.outstanding(PartyType.supplier))
              .getOrThrow();
          return Result.success(
            FinanceReportDocuments.outstanding(
              type: PartyType.supplier,
              generatedAt: now,
              balances: list,
              zero: zero,
            ),
          );
        case ReportKind.payments:
          final cash = (await _reports.cashFigures(filter)).getOrThrow();
          return Result.success(
            FinanceReportDocuments.payments(
              filter: filter,
              generatedAt: now,
              scope: scope,
              cash: cash,
            ),
          );
        case ReportKind.expenses:
          final report = (await _expenses.report(_expenseFilter(filter)))
              .getOrThrow();
          return Result.success(
            FinanceReportDocuments.expenses(
              filter: filter,
              generatedAt: now,
              report: report,
            ),
          );
        case ReportKind.profitability:
          final profit = await _profit(filter);
          final sales = (await _reports.salesFigures(filter)).getOrThrow();
          final expenses = (await _expenses.report(_expenseFilter(filter)))
              .getOrThrow();
          return Result.success(
            FinanceReportDocuments.profitability(
              filter: filter,
              generatedAt: now,
              sales: sales,
              profit: profit.getOrThrow(),
              expenseCount: expenses.count,
            ),
          );
      }
    } on FailureException catch (error) {
      return Result.failure(error.failure);
    }
  }

  ExpenseReportFilter _expenseFilter(ReportFilter filter) =>
      ExpenseReportFilter(from: filter.range.from, to: filter.range.to);

  Future<Map<String, UnitOfMeasure>> _unitMap() async {
    final units = await _units.search(includeArchived: true);
    return {for (final u in units.valueOrNull ?? <UnitOfMeasure>[]) u.id: u};
  }

  Future<List<String>> _scope(ReportKind kind, ReportFilter filter) async {
    final wantsProduct = kind.supportsProduct && filter.productId != null;
    final wantsCustomer = kind.supportsCustomer && filter.customerId != null;
    final wantsSupplier = kind.supportsSupplier && filter.supplierId != null;
    if (!wantsProduct && !wantsCustomer && !wantsSupplier) {
      return const [];
    }
    final choices = (await _options.load()).valueOrNull;
    return [
      if (wantsProduct)
        'Product: ${choices?.productName(filter.productId) ?? filter.productId}',
      if (wantsCustomer)
        'Customer: '
            '${choices?.customerName(filter.customerId) ?? filter.customerId}',
      if (wantsSupplier)
        'Supplier: '
            '${choices?.supplierName(filter.supplierId) ?? filter.supplierId}',
    ];
  }
}
