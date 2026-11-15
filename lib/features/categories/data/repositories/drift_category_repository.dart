import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/categories/data/mappers/category_mapper.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';

/// Drift implementation of [CategoryRepository].
final class DriftCategoryRepository implements CategoryRepository {
  /// Creates the repository.
  const DriftCategoryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<Category>>> search({
    String query = '',
    bool includeArchived = false,
  }) => guardDatabase(() async {
    final text = query.trim();
    final select = _db.select(_db.categories)
      ..where((t) {
        Expression<bool> predicate = const Constant(true);
        if (!includeArchived) {
          predicate = predicate & t.archivedAt.isNull();
        }
        if (text.isNotEmpty) {
          predicate = predicate & t.name.contains(text);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return (await select.get()).map(categoryFromRow).toList();
  });

  @override
  Future<Result<Category>> getById(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('Category not found.'));
    }
    return categoryFromRow(row);
  });

  @override
  Future<Result<bool>> nameExists(String name, {String? excludeId}) =>
      guardDatabase(() async {
        final table = _db.categories;
        final count = table.id.count();
        Expression<bool> predicate =
            table.archivedAt.isNull() &
            table.name.lower().equalsExp(Variable<String>(name).lower());
        if (excludeId != null) {
          predicate = predicate & table.id.equals(excludeId).not();
        }
        final query = _db.selectOnly(table)
          ..addColumns([count])
          ..where(predicate);
        final row = await query.getSingle();
        return (row.read(count) ?? 0) > 0;
      });

  @override
  Future<Result<int>> countProducts(
    String categoryId, {
    required bool activeOnly,
  }) => guardDatabase(() async {
    final products = _db.products;
    final count = products.id.count();
    Expression<bool> predicate = products.categoryId.equals(categoryId);
    if (activeOnly) {
      predicate = predicate & products.archivedAt.isNull();
    }
    final query = _db.selectOnly(products)
      ..addColumns([count])
      ..where(predicate);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  });

  @override
  Future<Result<void>> create(Category category) => guardDatabase(
    () => _db.into(_db.categories).insert(categoryToCompanion(category)),
  );

  @override
  Future<Result<void>> update(Category category) => guardDatabase(() async {
    final affected =
        await (_db.update(_db.categories)
              ..where((t) => t.id.equals(category.id)))
            .write(categoryToCompanion(category));
    if (affected == 0) {
      throw const FailureException(NotFoundFailure('Category not found.'));
    }
  });
}
