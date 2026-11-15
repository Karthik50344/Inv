import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';

/// Archives a category unless active products still use it.
final class ArchiveCategory {
  /// Creates the use case.
  const ArchiveCategory({
    required CategoryRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final CategoryRepository _repository;
  final Clock _clock;

  /// Archives category [id]. Archiving an archived category succeeds.
  Future<Result<void>> call(String id) async {
    final existing = await _repository.getById(id);
    final category = existing.valueOrNull;
    if (category == null) {
      return Result.failure(existing.failureOrNull!);
    }
    if (category.isArchived) {
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
          'Cannot archive "${category.name}": $used active '
          '${used == 1 ? 'product uses' : 'products use'} it. '
          'Move or archive them first.',
        ),
      );
    }
    return _repository.update(category.archived(_clock.now()));
  }
}
