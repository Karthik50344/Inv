import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/utils/date_only.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/domain/services/expense_period.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the expense report screen.
final class ExpenseReportState extends Equatable {
  /// Creates a state.
  const ExpenseReportState({
    this.status = ViewStatus.initial,
    this.period = ExpensePeriod.thisMonth,
    this.from,
    this.to,
    this.categoryId,
    this.categories = const [],
    this.report,
    this.message,
  });

  /// Loading status. `empty` means the period has no posted expenses.
  final ViewStatus status;

  /// Selected period preset.
  final ExpensePeriod period;

  /// First day of the range (date only).
  final DateTime? from;

  /// Last day of the range (date only).
  final DateTime? to;

  /// Category filter, `null` for all.
  final String? categoryId;

  /// Categories for the filter (archived ones included).
  final List<ExpenseCategory> categories;

  /// The loaded report.
  final ExpenseReport? report;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  ExpenseReportState copyWith({
    ViewStatus? status,
    ExpensePeriod? period,
    DateTime? from,
    DateTime? to,
    String? categoryId,
    bool clearCategory = false,
    List<ExpenseCategory>? categories,
    ExpenseReport? report,
    String? message,
  }) => ExpenseReportState(
    status: status ?? this.status,
    period: period ?? this.period,
    from: from ?? this.from,
    to: to ?? this.to,
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    categories: categories ?? this.categories,
    report: report ?? this.report,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    period,
    from,
    to,
    categoryId,
    categories,
    report,
    message,
  ];
}

/// Builds the expense report for a period and optional category.
class ExpenseReportCubit extends Cubit<ExpenseReportState> {
  /// Creates the cubit.
  ExpenseReportCubit({
    required ExpenseRepository expenses,
    required ExpenseCategoryRepository categories,
    required Clock clock,
  }) : _expenses = expenses,
       _categories = categories,
       _clock = clock,
       super(const ExpenseReportState());

  final ExpenseRepository _expenses;
  final ExpenseCategoryRepository _categories;
  final Clock _clock;

  DateTime get _today => dateOnlyUtc(_clock.now().toLocal());

  /// Loads the categories and the report of the current month.
  Future<void> load() async {
    final range = ExpensePeriod.thisMonth.rangeFor(_today)!;
    emit(
      state.copyWith(
        period: ExpensePeriod.thisMonth,
        from: range.from,
        to: range.to,
      ),
    );
    final categories = await _categories.search(includeArchived: true);
    if (isClosed) {
      return;
    }
    final failure = categories.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    emit(state.copyWith(categories: categories.valueOrNull));
    await refresh();
  }

  /// Selects a preset period. Use [setCustomRange] for [ExpensePeriod.custom].
  Future<void> setPeriod(ExpensePeriod period) {
    final range = period.rangeFor(_today);
    if (range == null) {
      return Future.value();
    }
    emit(state.copyWith(period: period, from: range.from, to: range.to));
    return refresh();
  }

  /// Selects a custom inclusive range. A reversed range is swapped.
  Future<void> setCustomRange(DateTime from, DateTime to) {
    var start = dateOnlyUtc(from);
    var end = dateOnlyUtc(to);
    if (end.isBefore(start)) {
      (start, end) = (end, start);
    }
    emit(state.copyWith(period: ExpensePeriod.custom, from: start, to: end));
    return refresh();
  }

  /// Filters by [categoryId]; `null` shows all categories.
  Future<void> setCategory(String? categoryId) {
    emit(
      categoryId == null
          ? state.copyWith(clearCategory: true)
          : state.copyWith(categoryId: categoryId),
    );
    return refresh();
  }

  /// Rebuilds the report for the current selection.
  Future<void> refresh() async {
    final from = state.from;
    final to = state.to;
    if (from == null || to == null) {
      return;
    }
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _expenses.report(
      ExpenseReportFilter(from: from, to: to, categoryId: state.categoryId),
    );
    if (isClosed) {
      return;
    }
    result.when(
      success: (report) => emit(
        state.copyWith(
          status: report.isEmpty && report.otherCurrencyCount == 0
              ? ViewStatus.empty
              : ViewStatus.loaded,
          report: report,
        ),
      ),
      failure: (failure) => emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }
}
