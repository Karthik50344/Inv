import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_categories.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the expense categories screen.
final class ExpenseCategoriesState extends Equatable {
  /// Creates a state.
  const ExpenseCategoriesState({
    this.status = ViewStatus.initial,
    this.categories = const [],
    this.query = '',
    this.includeArchived = false,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded categories.
  final List<ExpenseCategory> categories;

  /// Current search text.
  final String query;

  /// Whether archived categories are shown.
  final bool includeArchived;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  ExpenseCategoriesState copyWith({
    ViewStatus? status,
    List<ExpenseCategory>? categories,
    String? query,
    bool? includeArchived,
    String? message,
  }) => ExpenseCategoriesState(
    status: status ?? this.status,
    categories: categories ?? this.categories,
    query: query ?? this.query,
    includeArchived: includeArchived ?? this.includeArchived,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    categories,
    query,
    includeArchived,
    message,
  ];
}

/// Lists, searches and manages expense categories.
///
/// Create/update return their [Result] so the dialog can show field errors;
/// the list refreshes after every successful change.
class ExpenseCategoriesCubit extends Cubit<ExpenseCategoriesState> {
  /// Creates the cubit.
  ExpenseCategoriesCubit({
    required ExpenseCategoryRepository categories,
    required CreateExpenseCategory createCategory,
    required UpdateExpenseCategory updateCategory,
    required SetExpenseCategoryArchived setArchived,
  }) : _categories = categories,
       _create = createCategory,
       _update = updateCategory,
       _setArchived = setArchived,
       super(const ExpenseCategoriesState());

  final ExpenseCategoryRepository _categories;
  final CreateExpenseCategory _create;
  final UpdateExpenseCategory _update;
  final SetExpenseCategoryArchived _setArchived;

  /// Loads categories for the current query/filter.
  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _categories.search(
      query: state.query,
      includeArchived: state.includeArchived,
    );
    if (isClosed) {
      return;
    }
    result.when(
      success: (list) => emit(
        state.copyWith(
          status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
          categories: list,
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

  /// Applies a search query and reloads.
  Future<void> search(String query) {
    emit(state.copyWith(query: query));
    return load();
  }

  /// Shows or hides archived categories and reloads.
  Future<void> setIncludeArchived({required bool value}) {
    emit(state.copyWith(includeArchived: value));
    return load();
  }

  /// Creates a category.
  Future<Result<ExpenseCategory>> create(
    String name,
    String? description,
  ) async {
    final result = await _create(name: name, description: description);
    if (result.isSuccess) {
      await load();
    }
    return result;
  }

  /// Updates a category.
  Future<Result<ExpenseCategory>> update(
    String id,
    String name,
    String? description,
  ) async {
    final result = await _update(id: id, name: name, description: description);
    if (result.isSuccess) {
      await load();
    }
    return result;
  }

  /// Archives a category; a failure is reported via the state message.
  Future<void> archive(String id) => _run(_setArchived(id, archived: true));

  /// Restores a category; a failure is reported via the state message.
  Future<void> restore(String id) => _run(_setArchived(id, archived: false));

  Future<void> _run(Future<Result<void>> action) async {
    final result = await action;
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(message: failure.userMessage));
      return;
    }
    await load();
  }
}
