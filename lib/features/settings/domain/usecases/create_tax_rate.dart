import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/utils/decimal_text.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';

/// Validates and creates a tax rate from a percentage entered as text.
final class CreateTaxRate {
  /// Creates the use case.
  const CreateTaxRate({
    required TaxRateRepository repository,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _ids = ids,
       _clock = clock;

  final TaxRateRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;

  /// Creates a rate. [ratePercent] such as `18` or `12.5` (0-1000).
  Future<Result<TaxRate>> call({
    required String name,
    required String ratePercent,
    bool isExempt = false,
  }) async {
    final errors = FieldErrors()
      ..add(
        'name',
        Validators.requiredText(name, label: 'Name', maxLength: 60),
      );
    var rateBp = 0;
    if (!isExempt) {
      final parsed = parseScaledDecimal(ratePercent, scale: 2);
      if (parsed == null || parsed < 0 || parsed > 100000) {
        errors.add(
          'ratePercent',
          'Enter a rate between 0 and 1000 (max 2 decimals).',
        );
      } else {
        rateBp = parsed;
      }
    }
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final trimmed = name.trim();
    final exists = await _repository.nameExists(trimmed);
    if (exists.isFailure) {
      return Result.failure(exists.failureOrNull!);
    }
    if (exists.valueOrNull ?? false) {
      errors.add('name', 'A tax rate with this name already exists.');
      return Result.failure(errors.toFailure());
    }
    final now = _clock.now();
    final taxRate = TaxRate(
      id: _ids.newId(),
      name: trimmed,
      rateBp: rateBp,
      isExempt: isExempt,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _repository.create(taxRate);
    return saved.isFailure
        ? Result.failure(saved.failureOrNull!)
        : Result.success(taxRate);
  }
}
