import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_filter.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_summary.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the expense list.
final class ExpensesState extends Equatable {
  /// Creates a state.
  const ExpensesState({
    this.status = ViewStatus.initial,
    this.items = const [],
    this.filter = const ExpenseFilter(),
    this.categories = const [],
    this.postedTotal,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded expenses.
  final List<ExpenseSummary> items;

  /// Active filter.
  final ExpenseFilter filter;

  /// Categories for the category filter (including archived ones, so old
  /// expenses stay filterable).
  final List<ExpenseCategory> categories;

  /// Sum of the **posted** expenses in [items] (configured currency only).
  final Money? postedTotal;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  ExpensesState copyWith({
    ViewStatus? status,
    List<ExpenseSummary>? items,
    ExpenseFilter? filter,
    List<ExpenseCategory>? categories,
    Money? postedTotal,
    String? message,
  }) => ExpensesState(
    status: status ?? this.status,
    items: items ?? this.items,
    filter: filter ?? this.filter,
    categories: categories ?? this.categories,
    postedTotal: postedTotal ?? this.postedTotal,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    filter,
    categories,
    postedTotal,
    message,
  ];
}

/// Lists expenses with search, status, category and date filters.
class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  /// Creates the bloc.
  ExpensesBloc({
    required ExpenseRepository expenses,
    required ExpenseCategoryRepository categories,
    required SettingsRepository settings,
  }) : _expenses = expenses,
       _categories = categories,
       _settings = settings,
       super(const ExpensesState()) {
    on<ExpensesStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<ExpensesRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<ExpensesSearchChanged>((event, emit) {
      emit(state.copyWith(filter: state.filter.copyWith(query: event.query)));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<ExpensesStatusChanged>((event, emit) {
      emit(
        state.copyWith(
          filter: event.status == null
              ? state.filter.copyWith(clearStatus: true)
              : state.filter.copyWith(status: event.status),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<ExpensesCategoryChanged>((event, emit) {
      emit(
        state.copyWith(
          filter: event.categoryId == null
              ? state.filter.copyWith(clearCategory: true)
              : state.filter.copyWith(categoryId: event.categoryId),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<ExpensesRangeChanged>((event, emit) {
      emit(
        state.copyWith(
          filter: event.from == null && event.to == null
              ? state.filter.copyWith(clearRange: true)
              : ExpenseFilter(
                  query: state.filter.query,
                  status: state.filter.status,
                  categoryId: state.filter.categoryId,
                  from: event.from,
                  to: event.to,
                ),
        ),
      );
      return _load(emit);
    }, transformer: sequentialTransformer());
  }

  final ExpenseRepository _expenses;
  final ExpenseCategoryRepository _categories;
  final SettingsRepository _settings;

  Future<void> _load(Emitter<ExpensesState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final items = await _expenses.search(state.filter);
    final categories = await _categories.search(includeArchived: true);
    final currency = await _settings.getCurrencyConfig();
    final failure =
        items.failureOrNull ??
        categories.failureOrNull ??
        currency.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final list = items.valueOrNull!;
    final config = currency.valueOrNull!;
    var total = config.zero();
    for (final item in list) {
      if (item.status == DocumentStatus.posted &&
          item.total.currencyCode == config.currencyCode &&
          item.total.decimalPlaces == config.decimalPlaces) {
        total += item.total;
      }
    }
    emit(
      state.copyWith(
        status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        items: list,
        categories: categories.valueOrNull,
        postedTotal: total,
      ),
    );
  }
}
