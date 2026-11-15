import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';

/// Row -> entity.
Category categoryFromRow(CategoryRow row) => Category(
  id: row.id,
  name: row.name,
  description: row.description,
  createdAt: fromEpochMs(row.createdAt),
  updatedAt: fromEpochMs(row.updatedAt),
  archivedAt: fromEpochMsOrNull(row.archivedAt),
);

/// Entity -> insert/update companion.
CategoriesCompanion categoryToCompanion(Category category) =>
    CategoriesCompanion(
      id: Value(category.id),
      name: Value(category.name),
      description: Value(category.description),
      archivedAt: Value(toEpochMsOrNull(category.archivedAt)),
      createdAt: Value(toEpochMs(category.createdAt)),
      updatedAt: Value(toEpochMs(category.updatedAt)),
    );
