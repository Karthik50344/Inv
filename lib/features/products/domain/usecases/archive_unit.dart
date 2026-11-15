import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';

/// Archives a unit unless active products still use it.
final class ArchiveUnit {
  /// Creates the use case.
  const ArchiveUnit({required UnitRepository repository, required Clock clock})
    : _repository = repository,
      _clock = clock;

  final UnitRepository _repository;
  final Clock _clock;

  /// Archives unit [id]. Archiving an archived unit succeeds.
  Future<Result<void>> call(String id) async {
    final existing = await _repository.getById(id);
    final unit = existing.valueOrNull;
    if (unit == null) {
      return Result.failure(existing.failureOrNull!);
    }
    if (unit.isArchived) {
      return const Result.success(null);
    }
    final count = await _repository.countProducts(id, activeOnly: true);
    if (count.isFailure) {
      return Result.failure(count.failureOrNull!);
    }
    final used = count.valueOrNull ?? 0;
    if (used > 0) {
      return Result.failure(
        ValidationFailure(
          'Cannot archive "${unit.name}": $used active '
          '${used == 1 ? 'product uses' : 'products use'} it.',
        ),
      );
    }
    return _repository.update(unit.archived(_clock.now()));
  }
}
