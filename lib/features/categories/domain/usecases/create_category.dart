import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';

/// Validates a category's fields (shared by create and update).
FieldErrors validateCategoryFields(String name, String? description) =>
    FieldErrors()
      ..add('name', Validators.requiredText(name, label: 'Name', maxLength: 80))
      ..add(
        'description',
        Validators.optionalText(
          description,
          label: 'Description',
          maxLength: 300,
        ),
      );

/// Creates a category after validating name rules.
final class CreateCategory {
  /// Creates the use case.
  const CreateCategory({
    required CategoryRepository repository,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _ids = ids,
       _clock = clock;

  final CategoryRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;

  /// Creates and returns the new category.
  Future<Result<Category>> call({
    required String name,
    String? description,
  }) async {
    final errors = validateCategoryFields(name, description);
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final trimmed = name.trim();
    final exists = await _repository.nameExists(trimmed);
    if (exists.isFailure) {
      return Result.failure(exists.failureOrNull!);
    }
    if (exists.valueOrNull ?? false) {
      errors.add('name', 'A category named "$trimmed" already exists.');
      return Result.failure(errors.toFailure());
    }
    final now = _clock.now();
    final category = Category(
      id: _ids.newId(),
      name: trimmed,
      description: blankToNull(description),
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _repository.create(category);
    return saved.isFailure
        ? Result.failure(saved.failureOrNull!)
        : Result.success(category);
  }
}
