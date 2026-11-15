import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/domain/usecases/create_unit.dart';

/// Updates a unit. Precision may be increased freely but cannot be reduced
/// once any product uses the unit, because existing quantities could stop
/// fitting the unit's precision.
final class UpdateUnit {
  /// Creates the use case.
  const UpdateUnit({required UnitRepository repository, required Clock clock})
    : _repository = repository,
      _clock = clock;

  final UnitRepository _repository;
  final Clock _clock;

  /// Updates unit [id] and returns the saved value.
  Future<Result<UnitOfMeasure>> call({
    required String id,
    required String name,
    required String symbol,
    required int decimalPlaces,
  }) async {
    final errors = validateUnitFields(
      name: name,
      symbol: symbol,
      decimalPlaces: decimalPlaces,
    );
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final existing = await _repository.getById(id);
    final unit = existing.valueOrNull;
    if (unit == null) {
      return Result.failure(existing.failureOrNull!);
    }
    final trimmedSymbol = symbol.trim();
    final exists = await _repository.symbolExists(trimmedSymbol, excludeId: id);
    if (exists.isFailure) {
      return Result.failure(exists.failureOrNull!);
    }
    if (exists.valueOrNull ?? false) {
      errors.add(
        'symbol',
        'A unit with symbol "$trimmedSymbol" already exists.',
      );
      return Result.failure(errors.toFailure());
    }
    if (decimalPlaces < unit.decimalPlaces) {
      final used = await _repository.countProducts(id, activeOnly: false);
      if (used.isFailure) {
        return Result.failure(used.failureOrNull!);
      }
      if ((used.valueOrNull ?? 0) > 0) {
        errors.add(
          'decimalPlaces',
          'Precision cannot be reduced while products use this unit.',
        );
        return Result.failure(errors.toFailure());
      }
    }
    final updated = unit.withDetails(
      name: name.trim(),
      symbol: trimmedSymbol,
      decimalPlaces: decimalPlaces,
      updatedAt: _clock.now(),
    );
    final saved = await _repository.update(updated);
    return saved.isFailure
        ? Result.failure(saved.failureOrNull!)
        : Result.success(updated);
  }
}
