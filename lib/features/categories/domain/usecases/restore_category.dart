import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';

/// Restores an archived category if its name is still free.
final class RestoreCategory {
  /// Creates the use case.
  const RestoreCategory({
    required CategoryRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final CategoryRepository _repository;
  final Clock _clock;

  /// Restores category [id].
  Future<Result<void>> call(String id) async {
    final existing = await _repository.getById(id);
    final category = existing.valueOrNull;
    if (category == null) {
      return Result.failure(existing.failureOrNull!);
    }
    if (!category.isArchived) {
      return const Result.success(null);
    }
    final exists = await _repository.nameExists(
      category.name,
      excludeId: category.id,
    );
    if (exists.isFailure) {
      return Result.failure(exists.failureOrNull!);
    }
    if (exists.valueOrNull ?? false) {
      return Result.failure(
        DuplicateEntryFailure(
          'Cannot restore: an active category named "${category.name}" '
          'already exists.',
        ),
      );
    }
    return _repository.update(category.restored(_clock.now()));
  }
}
