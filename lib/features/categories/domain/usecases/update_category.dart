import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/categories/domain/usecases/create_category.dart';
import 'package:inventrix/core/validators/validators.dart';

/// Updates a category's name and description.
final class UpdateCategory {
  /// Creates the use case.
  const UpdateCategory({
    required CategoryRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final CategoryRepository _repository;
  final Clock _clock;

  /// Updates category [id] and returns the saved value.
  Future<Result<Category>> call({
    required String id,
    required String name,
    String? description,
  }) async {
    final errors = validateCategoryFields(name, description);
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final existing = await _repository.getById(id);
    final category = existing.valueOrNull;
    if (category == null) {
      return Result.failure(existing.failureOrNull!);
    }
    final trimmed = name.trim();
    if (!category.isArchived) {
      final exists = await _repository.nameExists(trimmed, excludeId: id);
      if (exists.isFailure) {
        return Result.failure(exists.failureOrNull!);
      }
      if (exists.valueOrNull ?? false) {
        errors.add('name', 'A category named "$trimmed" already exists.');
        return Result.failure(errors.toFailure());
      }
    }
    final updated = category.withDetails(
      name: trimmed,
      description: blankToNull(description),
      updatedAt: _clock.now(),
    );
    final saved = await _repository.update(updated);
    return saved.isFailure
        ? Result.failure(saved.failureOrNull!)
        : Result.success(updated);
  }
}
