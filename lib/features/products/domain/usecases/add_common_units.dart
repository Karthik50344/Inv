import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/domain/usecases/create_unit.dart';

/// Adds commonly used units that do not exist yet (idempotent).
final class AddCommonUnits {
  /// Creates the use case.
  const AddCommonUnits({
    required UnitRepository repository,
    required CreateUnit createUnit,
  }) : _repository = repository,
       _createUnit = createUnit;

  final UnitRepository _repository;
  final CreateUnit _createUnit;

  static const List<({String name, String symbol, int decimals})> _common = [
    (name: 'Piece', symbol: 'pcs', decimals: 0),
    (name: 'Box', symbol: 'box', decimals: 0),
    (name: 'Dozen', symbol: 'doz', decimals: 0),
    (name: 'Kilogram', symbol: 'kg', decimals: 3),
    (name: 'Gram', symbol: 'g', decimals: 0),
    (name: 'Litre', symbol: 'l', decimals: 3),
    (name: 'Millilitre', symbol: 'ml', decimals: 0),
    (name: 'Metre', symbol: 'm', decimals: 2),
  ];

  /// Creates the missing units and returns how many were added.
  Future<Result<int>> call() async {
    var added = 0;
    for (final unit in _common) {
      final exists = await _repository.symbolExists(unit.symbol);
      if (exists.isFailure) {
        return Result.failure(exists.failureOrNull!);
      }
      if (exists.valueOrNull ?? false) {
        continue;
      }
      final created = await _createUnit(
        name: unit.name,
        symbol: unit.symbol,
        decimalPlaces: unit.decimals,
      );
      if (created.isFailure) {
        return Result.failure(created.failureOrNull!);
      }
      added++;
    }
    return Result.success(added);
  }
}
