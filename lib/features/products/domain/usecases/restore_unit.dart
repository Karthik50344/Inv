import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';

/// Restores an archived unit.
final class RestoreUnit {
  /// Creates the use case.
  const RestoreUnit({required UnitRepository repository, required Clock clock})
    : _repository = repository,
      _clock = clock;

  final UnitRepository _repository;
  final Clock _clock;

  /// Restores unit [id]. Restoring an active unit succeeds.
  Future<Result<void>> call(String id) async {
    final existing = await _repository.getById(id);
    final unit = existing.valueOrNull;
    if (unit == null) {
      return Result.failure(existing.failureOrNull!);
    }
    if (!unit.isArchived) {
      return const Result.success(null);
    }
    return _repository.update(unit.restored(_clock.now()));
  }
}
