import 'package:equatable/equatable.dart';
import 'package:inventrix/core/utils/rounding.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Gross profit and operating result of a period.
///
/// Assumptions (also printed on the profitability report):
/// - revenue is **net sales**: posted sales minus sales returns, excluding
///   sales tax, in the period of the invoice or return date;
/// - cost of goods sold comes from the stock ledger at weighted average
///   cost, so it is what the sold goods cost when they left the shelf;
///   goods returned into stock reduce it, goods returned but written off do
///   not;
/// - purchases are **not** an expense: stock is an asset until it is sold;
/// - operating expenses are posted expenses **excluding tax**, in the
///   period of the expense date;
/// - cash received is not revenue and cash paid is not cost.
final class ProfitFigures extends Equatable {
  /// Creates figures from the three inputs.
  const ProfitFigures({
    required this.netSales,
    required this.costOfGoodsSold,
    required this.expenses,
  });

  /// Net sales (after returns, excluding tax).
  final Money netSales;

  /// Cost of the goods sold.
  final Money costOfGoodsSold;

  /// Posted expenses excluding tax.
  final Money expenses;

  /// [netSales] minus [costOfGoodsSold].
  Money get grossProfit => netSales - costOfGoodsSold;

  /// [grossProfit] minus [expenses]; negative means a loss.
  Money get operatingResult => grossProfit - expenses;

  /// Gross margin in basis points of net sales; `null` without sales.
  int? get grossMarginBasisPoints => _margin(grossProfit);

  /// Operating margin in basis points of net sales; `null` without sales.
  int? get operatingMarginBasisPoints => _margin(operatingResult);

  int? _margin(Money part) => netSales.isPositive
      ? roundedMulDiv(part.minorUnits, 10000, netSales.minorUnits)
      : null;

  @override
  List<Object?> get props => [netSales, costOfGoodsSold, expenses];
}
