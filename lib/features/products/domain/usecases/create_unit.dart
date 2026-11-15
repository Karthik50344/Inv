import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';

/// Validates a unit's fields (shared by create and update).
FieldErrors validateUnitFields({
  required String name,
  required String symbol,
  required int decimalPlaces,
}) {
  final errors = FieldErrors()
    ..add('name', Validators.requiredText(name, label: 'Name', maxLength: 40))
    ..add(
      'symbol',
      Validators.requiredText(symbol, label: 'Symbol', maxLength: 10),
    );
  if (decimalPlaces < 0 || decimalPlaces > 3) {
    errors.add('decimalPlaces', 'Precision must be between 0 and 3 decimals.');
  }
  return errors;
}

/// Creates a unit of measurement.
final class CreateUnit {
  /// Creates the use case.
  const CreateUnit({
    required UnitRepository repository,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _ids = ids,
       _clock = clock;

  final UnitRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;

  /// Creates and returns the new unit.
  Future<Result<UnitOfMeasure>> call({
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
    final trimmedSymbol = symbol.trim();
    final exists = await _repository.symbolExists(trimmedSymbol);
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
    final now = _clock.now();
    final unit = UnitOfMeasure(
      id: _ids.newId(),
      name: name.trim(),
      symbol: trimmedSymbol,
      decimalPlaces: decimalPlaces,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _repository.create(unit);
    return saved.isFailure
        ? Result.failure(saved.failureOrNull!)
        : Result.success(unit);
  }
}
