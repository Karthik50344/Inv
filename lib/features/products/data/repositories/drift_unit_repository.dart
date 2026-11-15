import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/data/mappers/unit_mapper.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';

/// Drift implementation of [UnitRepository].
final class DriftUnitRepository implements UnitRepository {
  /// Creates the repository.
  const DriftUnitRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<UnitOfMeasure>>> search({
    String query = '',
    bool includeArchived = false,
  }) => guardDatabase(() async {
    final text = query.trim();
    final select = _db.select(_db.units)
      ..where((t) {
        Expression<bool> predicate = const Constant(true);
        if (!includeArchived) {
          predicate = predicate & t.archivedAt.isNull();
        }
        if (text.isNotEmpty) {
          predicate =
              predicate & (t.name.contains(text) | t.symbol.contains(text));
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return (await select.get()).map(unitFromRow).toList();
  });

  @override
  Future<Result<UnitOfMeasure>> getById(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.units,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('Unit not found.'));
    }
    return unitFromRow(row);
  });

  @override
  Future<Result<bool>> symbolExists(String symbol, {String? excludeId}) =>
      guardDatabase(() async {
        final table = _db.units;
        final count = table.id.count();
        Expression<bool> predicate = table.symbol.lower().equalsExp(
          Variable<String>(symbol).lower(),
        );
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
    String unitId, {
    required bool activeOnly,
  }) => guardDatabase(() async {
    final products = _db.products;
    final count = products.id.count();
    Expression<bool> predicate = products.unitId.equals(unitId);
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
  Future<Result<void>> create(UnitOfMeasure unit) =>
      guardDatabase(() => _db.into(_db.units).insert(unitToCompanion(unit)));

  @override
  Future<Result<void>> update(UnitOfMeasure unit) => guardDatabase(() async {
    final affected = await (_db.update(
      _db.units,
    )..where((t) => t.id.equals(unit.id))).write(unitToCompanion(unit));
    if (affected == 0) {
      throw const FailureException(NotFoundFailure('Unit not found.'));
    }
  });
}
