import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';

/// Validates and normalises a classification entered by the user.
///
/// It checks only the *shape* of a code (digits, length, goods versus
/// services). It never decides whether a code exists, never suggests one
/// and needs no network: the user is the source of every code.
abstract final class ClassificationValidator {
  static final RegExp _digits = RegExp(r'^[0-9]+$');
  static final RegExp _customCode = RegExp(r'^[A-Za-z0-9 ._/\-]+$');
  static final RegExp _customSystem = RegExp(r'^[a-z0-9._\-]+$');
  static final RegExp _country = RegExp(r'^[A-Za-z]{2}$');

  /// Builds a [ProductClassification] or fails with a [ValidationFailure]
  /// whose `fieldErrors` use `system`, `code`, `description`, `country` and
  /// `type`.
  static Result<ProductClassification> build({
    required String id,
    required String productId,
    required String systemText,
    required String codeText,
    required ClassificationType type,
    required bool isPrimary,
    required DateTime now,
    String descriptionText = '',
    String countryText = '',
    DateTime? createdAt,
  }) {
    final errors = <String, String>{};

    final systemRaw = systemText.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '-',
    );
    ClassificationSystem? system;
    if (systemRaw.isEmpty) {
      errors['system'] = 'Choose a classification system.';
    } else if (systemRaw.length > 30 || !_customSystem.hasMatch(systemRaw)) {
      errors['system'] =
          'Use up to 30 letters, numbers, dots, dashes or underscores.';
    } else {
      system = ClassificationSystem(systemRaw);
    }

    var code = codeText.trim();
    if (code.isEmpty) {
      errors['code'] = 'Enter the classification code.';
    } else if (system != null) {
      if (system.isBuiltIn) {
        code = code.replaceAll(RegExp(r'[\s.\-]'), '');
        final problem = _builtInProblem(system, code);
        if (problem != null) {
          errors['code'] = problem;
        }
      } else if (code.length > 32 || !_customCode.hasMatch(code)) {
        errors['code'] =
            'Use up to 32 letters, numbers, spaces, dots, dashes or slashes.';
      } else {
        code = code.replaceAll(RegExp(r'\s+'), ' ').toUpperCase();
      }
    }

    if (system == ClassificationSystem.sac &&
        type != ClassificationType.services) {
      errors['type'] = 'SAC codes are for services.';
    }
    if ((system == ClassificationSystem.hsn ||
            system == ClassificationSystem.hs) &&
        type != ClassificationType.goods) {
      errors['type'] = 'HSN and HS codes are for goods.';
    }

    final description = descriptionText.trim();
    if (description.length > 200) {
      errors['description'] = 'The description must be at most 200 characters.';
    }

    final countryRaw = countryText.trim();
    if (countryRaw.isNotEmpty && !_country.hasMatch(countryRaw)) {
      errors['country'] = 'Use a 2-letter country code, for example IN.';
    }

    if (errors.isNotEmpty || system == null) {
      return Result.failure(
        ValidationFailure(
          'Please correct the highlighted fields.',
          fieldErrors: Map.unmodifiable(errors),
        ),
      );
    }
    return Result.success(
      ProductClassification(
        id: id,
        productId: productId,
        system: system,
        code: code,
        description: description.isEmpty ? null : description,
        countryCode: countryRaw.isEmpty ? null : countryRaw.toUpperCase(),
        type: type,
        isPrimary: isPrimary,
        createdAt: createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  static String? _builtInProblem(ClassificationSystem system, String code) {
    if (!_digits.hasMatch(code)) {
      return '${system.displayName} codes contain digits only.';
    }
    if (system == ClassificationSystem.sac) {
      return code.length == 6 ? null : 'A SAC code has 6 digits.';
    }
    if (system == ClassificationSystem.hsn) {
      return const {2, 4, 6, 8}.contains(code.length)
          ? null
          : 'An HSN code has 2, 4, 6 or 8 digits.';
    }
    return const {2, 4, 6, 8, 10, 12}.contains(code.length)
        ? null
        : 'An HS code has 2, 4, 6, 8, 10 or 12 digits.';
  }
}
