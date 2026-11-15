import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/categories/domain/usecases/archive_category.dart';
import 'package:inventrix/features/categories/domain/usecases/create_category.dart';
import 'package:inventrix/features/categories/domain/usecases/restore_category.dart';
import 'package:inventrix/features/categories/domain/usecases/update_category.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_state.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Lists, searches and manages categories.
///
/// Create/update return their [Result] so the editing dialog can show field
/// errors; the list refreshes after every successful change.
class CategoryCubit extends Cubit<CategoryState> {
  /// Creates the cubit.
  CategoryCubit({
    required CategoryRepository repository,
    required CreateCategory createCategory,
    required UpdateCategory updateCategory,
    required ArchiveCategory archiveCategory,
    required RestoreCategory restoreCategory,
  }) : _repository = repository,
       _create = createCategory,
       _update = updateCategory,
       _archive = archiveCategory,
       _restore = restoreCategory,
       super(const CategoryState());

  final CategoryRepository _repository;
  final CreateCategory _create;
  final UpdateCategory _update;
  final ArchiveCategory _archive;
  final RestoreCategory _restore;

  /// Loads categories for the current query/filter.
  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _repository.search(
      query: state.query,
      includeArchived: state.includeArchived,
    );
    if (isClosed) {
      return;
    }
    result.when(
      success: (categories) => emit(
        state.copyWith(
          status: categories.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
          categories: categories,
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
  Future<Result<Category>> create(String name, String? description) async {
    final result = await _create(name: name, description: description);
    if (result.isSuccess) {
      await load();
    }
    return result;
  }

  /// Updates a category.
  Future<Result<Category>> update(
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

  /// Archives a category; a failure is reported via [CategoryState.message].
  Future<void> archive(String id) => _run(_archive(id));

  /// Restores a category; a failure is reported via [CategoryState.message].
  Future<void> restore(String id) => _run(_restore(id));

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
