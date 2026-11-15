import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/expenses/data/mappers/expense_mapper.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';

/// Drift implementation of [ExpenseCategoryRepository].
final class DriftExpenseCategoryRepository
    implements ExpenseCategoryRepository {
  /// Creates the repository.
  const DriftExpenseCategoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<ExpenseCategory>>> search({
    String query = '',
    bool includeArchived = false,
  }) => guardDatabase(() async {
    final text = query.trim();
    final select = _db.select(_db.expenseCategories)
      ..where((t) {
        Expression<bool> condition = const Constant(true);
        if (!includeArchived) {
          condition = condition & t.archivedAt.isNull();
        }
        if (text.isNotEmpty) {
          condition = condition & t.name.contains(text);
        }
        return condition;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    final rows = await select.get();
    return rows.map(categoryFromRow).toList();
  });

  @override
  Future<Result<ExpenseCategory>> getById(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.expenseCategories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(
        NotFoundFailure('Expense category not found.'),
      );
    }
    return categoryFromRow(row);
  });

  @override
  Future<Result<bool>> nameExists(String name, {String? excludeId}) =>
      guardDatabase(() async {
        final rows =
            await (_db.select(_db.expenseCategories)..where(
                  (t) =>
                      t.archivedAt.isNull() &
                      t.name.lower().equals(name.trim().toLowerCase()),
                ))
                .get();
        return rows.any((row) => row.id != excludeId);
      });

  @override
  Future<Result<void>> create(ExpenseCategory category) => guardDatabase(
    () => _db.into(_db.expenseCategories).insert(categoryToCompanion(category)),
  );

  @override
  Future<Result<void>> update(ExpenseCategory category) =>
      guardDatabase(() async {
        final affected =
            await (_db.update(_db.expenseCategories)
                  ..where((t) => t.id.equals(category.id)))
                .write(categoryToCompanion(category));
        if (affected == 0) {
          throw const FailureException(
            NotFoundFailure('Expense category not found.'),
          );
        }
      });
}
