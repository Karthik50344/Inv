import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';

/// Validates an expense category's fields (shared by create and update).
FieldErrors validateExpenseCategoryFields(String name, String? description) =>
    FieldErrors()
      ..add('name', Validators.requiredText(name, label: 'Name', maxLength: 60))
      ..add(
        'description',
        Validators.optionalText(
          description,
          label: 'Description',
          maxLength: 200,
        ),
      );

/// Creates an expense category after validating its name.
final class CreateExpenseCategory {
  /// Creates the use case.
  const CreateExpenseCategory({
    required ExpenseCategoryRepository categories,
    required IdGenerator ids,
    required Clock clock,
  }) : _categories = categories,
       _ids = ids,
       _clock = clock;

  final ExpenseCategoryRepository _categories;
  final IdGenerator _ids;
  final Clock _clock;

  /// Creates and returns the new category.
  Future<Result<ExpenseCategory>> call({
    required String name,
    String? description,
  }) async {
    final errors = validateExpenseCategoryFields(name, description);
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final trimmed = name.trim();
    final exists = await _categories.nameExists(trimmed);
    if (exists.isFailure) {
      return Result.failure(exists.failureOrNull!);
    }
    if (exists.valueOrNull ?? false) {
      errors.add('name', 'A category named "$trimmed" already exists.');
      return Result.failure(errors.toFailure());
    }
    final now = _clock.now();
    final category = ExpenseCategory(
      id: _ids.newId(),
      name: trimmed,
      description: blankToNull(description),
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _categories.create(category);
    final failure = saved.failureOrNull;
    if (failure is DuplicateEntryFailure) {
      errors.add('name', 'A category named "$trimmed" already exists.');
      return Result.failure(errors.toFailure());
    }
    return failure != null ? Result.failure(failure) : Result.success(category);
  }
}

/// Renames or re-describes an expense category.
///
/// Expenses keep the name they were saved with, so renaming never rewrites
/// posted history.
final class UpdateExpenseCategory {
  /// Creates the use case.
  const UpdateExpenseCategory({
    required ExpenseCategoryRepository categories,
    required Clock clock,
  }) : _categories = categories,
       _clock = clock;

  final ExpenseCategoryRepository _categories;
  final Clock _clock;

  /// Updates category [id] and returns it.
  Future<Result<ExpenseCategory>> call({
    required String id,
    required String name,
    String? description,
  }) async {
    final errors = validateExpenseCategoryFields(name, description);
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final loaded = await _categories.getById(id);
    final existing = loaded.valueOrNull;
    if (existing == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    final trimmed = name.trim();
    if (!existing.isArchived) {
      final exists = await _categories.nameExists(trimmed, excludeId: id);
      if (exists.isFailure) {
        return Result.failure(exists.failureOrNull!);
      }
      if (exists.valueOrNull ?? false) {
        errors.add('name', 'A category named "$trimmed" already exists.');
        return Result.failure(errors.toFailure());
      }
    }
    final updated = existing.withDetails(
      name: trimmed,
      description: blankToNull(description),
      updatedAt: _clock.now(),
    );
    final saved = await _categories.update(updated);
    final failure = saved.failureOrNull;
    if (failure is DuplicateEntryFailure) {
      errors.add('name', 'A category named "$trimmed" already exists.');
      return Result.failure(errors.toFailure());
    }
    return failure != null ? Result.failure(failure) : Result.success(updated);
  }
}

/// Archives or restores an expense category.
///
/// Archiving only hides the category from new expenses; recorded expenses
/// keep it. A draft that still uses an archived category cannot be posted
/// until another category is chosen or this one is restored.
final class SetExpenseCategoryArchived {
  /// Creates the use case.
  const SetExpenseCategoryArchived({
    required ExpenseCategoryRepository categories,
    required Clock clock,
  }) : _categories = categories,
       _clock = clock;

  final ExpenseCategoryRepository _categories;
  final Clock _clock;

  /// Archives ([archived] true) or restores category [id]. Doing either
  /// twice succeeds without change.
  Future<Result<void>> call(String id, {required bool archived}) async {
    final loaded = await _categories.getById(id);
    final category = loaded.valueOrNull;
    if (category == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    if (category.isArchived == archived) {
      return const Result.success(null);
    }
    if (!archived) {
      // Restoring must not create a second active category of that name.
      final clash = await _categories.nameExists(category.name, excludeId: id);
      if (clash.isFailure) {
        return Result.failure(clash.failureOrNull!);
      }
      if (clash.valueOrNull ?? false) {
        return Result.failure(
          ValidationFailure(
            'Another active category is already named "${category.name}". '
            'Rename one of them first.',
          ),
        );
      }
    }
    final now = _clock.now();
    return _categories.update(
      archived ? category.archived(now) : category.restored(now),
    );
  }
}
