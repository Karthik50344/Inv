import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';

/// Persistence contract for units of measurement.
abstract interface class UnitRepository {
  /// Lists units ordered by name, filtered by [query] (name or symbol).
  Future<Result<List<UnitOfMeasure>>> search({
    String query = '',
    bool includeArchived = false,
  });

  /// Loads one unit; fails with `NotFoundFailure` if missing.
  Future<Result<UnitOfMeasure>> getById(String id);

  /// Whether any unit (archived or not) uses [symbol] (case-insensitive),
  /// ignoring [excludeId].
  Future<Result<bool>> symbolExists(String symbol, {String? excludeId});

  /// Number of products using [unitId]; only non-archived when [activeOnly].
  Future<Result<int>> countProducts(String unitId, {required bool activeOnly});

  /// Inserts a new unit.
  Future<Result<void>> create(UnitOfMeasure unit);

  /// Replaces an existing unit (also used for archive/restore).
  Future<Result<void>> update(UnitOfMeasure unit);
}
