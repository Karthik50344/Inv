import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_repository.dart';
import 'package:inventrix/features/reports/domain/services/profit_calculator.dart';

/// Net sales, cost of goods sold and operating expenses of a period.
///
/// The profitability report and the dashboard both use this use case, so
/// they always show the same estimate. See [ProfitFigures] for the
/// assumptions.
final class GetProfitFigures {
  /// Creates the use case.
  const GetProfitFigures({
    required ReportRepository reports,
    required ExpenseRepository expenses,
  }) : _reports = reports,
       _expenses = expenses;

  final ReportRepository _reports;
  final ExpenseRepository _expenses;

  /// Reads the three inputs for [filter]'s range.
  Future<Result<ProfitFigures>> call(ReportFilter filter) async {
    try {
      final sales = (await _reports.salesFigures(filter)).getOrThrow();
      final cost = (await _reports.costOfGoodsSold(filter.range)).getOrThrow();
      final expenses = (await _expenses.report(
        ExpenseReportFilter(from: filter.range.from, to: filter.range.to),
      )).getOrThrow();
      return Result.success(
        ProfitFigures(
          netSales: sales.netAfterReturns,
          costOfGoodsSold: cost,
          expenses: expenses.net,
        ),
      );
    } on FailureException catch (error) {
      return Result.failure(error.failure);
    }
  }
}
