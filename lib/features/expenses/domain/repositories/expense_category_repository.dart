import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';

/// Persistence contract for expense categories.
abstract interface class ExpenseCategoryRepository {
  /// Lists categories ordered by name, filtered by [query] (name contains).
  Future<Result<List<ExpenseCategory>>> search({
    String query = '',
    bool includeArchived = false,
  });

  /// Loads one category; fails with `NotFoundFailure` if missing.
  Future<Result<ExpenseCategory>> getById(String id);

  /// Whether an *active* category named [name] exists (case-insensitive),
  /// ignoring [excludeId].
  Future<Result<bool>> nameExists(String name, {String? excludeId});

  /// Inserts a new category.
  Future<Result<void>> create(ExpenseCategory category);

  /// Replaces an existing category (also used for archive/restore).
  Future<Result<void>> update(ExpenseCategory category);
}
