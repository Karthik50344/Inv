import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Criteria of an expense report: a date range and an optional category.
final class ExpenseReportFilter extends Equatable {
  /// Creates a filter. [from] and [to] are inclusive dates.
  const ExpenseReportFilter({
    required this.from,
    required this.to,
    this.categoryId,
  });

  /// First day to include (date only).
  final DateTime from;

  /// Last day to include (date only).
  final DateTime to;

  /// Restrict to one category.
  final String? categoryId;

  @override
  List<Object?> get props => [from, to, categoryId];
}

/// Totals of the posted expenses of one category.
final class ExpenseCategoryTotal extends Equatable {
  /// Creates a total.
  const ExpenseCategoryTotal({
    required this.categoryId,
    required this.categoryName,
    required this.count,
    required this.net,
    required this.tax,
    required this.total,
  });

  /// Category id.
  final String categoryId;

  /// Category name (as recorded on the expenses).
  final String categoryName;

  /// Number of expenses.
  final int count;

  /// Amount excluding tax.
  final Money net;

  /// Tax paid.
  final Money tax;

  /// Amount including tax.
  final Money total;

  @override
  List<Object?> get props => [categoryId, categoryName, count, net, tax, total];
}

/// Posted expenses within a period.
///
/// Assumptions (documented in `docs/workflows/expenses.md`):
/// - only **posted** expenses count; drafts, cancelled and voided ones do
///   not;
/// - an expense belongs to the period of its **expense date**, not the day
///   it was recorded;
/// - amounts are what was paid ([total], tax included); [net] and [tax] show
///   the split;
/// - only expenses in the configured currency are added up; the others are
///   counted in [otherCurrencyCount] so nothing disappears silently.
final class ExpenseReport extends Equatable {
  /// Creates a report.
  const ExpenseReport({
    required this.filter,
    required this.count,
    required this.net,
    required this.tax,
    required this.total,
    required this.byCategory,
    this.otherCurrencyCount = 0,
  });

  /// The criteria the report was built for.
  final ExpenseReportFilter filter;

  /// Number of expenses counted.
  final int count;

  /// Amount excluding tax.
  final Money net;

  /// Tax paid.
  final Money tax;

  /// Amount including tax.
  final Money total;

  /// Totals per category, largest first.
  final List<ExpenseCategoryTotal> byCategory;

  /// Posted expenses in the period that are in another currency and were
  /// left out of the totals.
  final int otherCurrencyCount;

  /// Whether nothing was recorded in the period.
  bool get isEmpty => count == 0;

  @override
  List<Object?> get props => [
    filter,
    count,
    net,
    tax,
    total,
    byCategory,
    otherCurrencyCount,
  ];
}
