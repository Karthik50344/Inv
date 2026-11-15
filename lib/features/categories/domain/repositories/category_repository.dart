import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';

/// Persistence contract for categories.
abstract interface class CategoryRepository {
  /// Lists categories ordered by name, filtered by [query] (name contains).
  Future<Result<List<Category>>> search({
    String query = '',
    bool includeArchived = false,
  });

  /// Loads one category; fails with `NotFoundFailure` if missing.
  Future<Result<Category>> getById(String id);

  /// Whether an *active* category named [name] exists (case-insensitive),
  /// ignoring [excludeId].
  Future<Result<bool>> nameExists(String name, {String? excludeId});

  /// Number of products assigned to [categoryId]; only non-archived products
  /// when [activeOnly] is true.
  Future<Result<int>> countProducts(
    String categoryId, {
    required bool activeOnly,
  });

  /// Inserts a new category.
  Future<Result<void>> create(Category category);

  /// Replaces an existing category (also used for archive/restore).
  Future<Result<void>> update(Category category);
}
