import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/utils/decimal_text.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Renames a tax rate, or changes its percentage while nothing uses it.
///
/// Invoice lines keep the rate they were posted with, so history is safe
/// either way; the guard stops a rate that products and expenses point at
/// from silently changing what they charge. For a rate in use, create a new
/// rate and archive the old one.
final class UpdateTaxRate {
  /// Creates the use case.
  const UpdateTaxRate({
    required TaxRateRepository repository,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final TaxRateRepository _repository;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Updates the rate [id]. [ratePercent] is text such as `18` or `12.5`.
  Future<Result<TaxRate>> call({
    required String id,
    required String name,
    required String ratePercent,
    required bool isExempt,
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
    return _transactions.runResult(() async {
      final current = (await _repository.getById(id)).getOrThrow();
      final duplicate = (await _repository.nameExists(
        trimmed,
        excludingId: id,
      )).getOrThrow();
      if (duplicate && !current.isArchived) {
        throw FailureException(
          (FieldErrors()
                ..add('name', 'A tax rate with this name already exists.'))
              .toFailure(),
        );
      }
      final rateChanged =
          current.rateBp != rateBp || current.isExempt != isExempt;
      if (rateChanged && (await _repository.isInUse(id)).getOrThrow()) {
        throw const FailureException(
          ValidationFailure(
            'Products or expenses already use this rate, so its percentage '
            'cannot change. Create a new rate and archive this one.',
          ),
        );
      }
      if (current.name == trimmed && !rateChanged) {
        return current;
      }
      final updated = TaxRate(
        id: current.id,
        name: trimmed,
        rateBp: rateBp,
        isExempt: isExempt,
        createdAt: current.createdAt,
        updatedAt: _clock.now(),
        archivedAt: current.archivedAt,
      );
      (await _repository.update(updated)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: 'tax_rate',
          entityId: id,
          action: 'updated',
          summary: 'Tax rate "${updated.name}" updated.',
          occurredAt: _clock.now(),
        ),
      )).getOrThrow();
      return updated;
    });
  }
}

/// Archives or restores a tax rate. Archived rates disappear from the
/// pickers but stay on products and documents that already use them.
final class SetTaxRateArchived {
  /// Creates the use case.
  const SetTaxRateArchived({
    required TaxRateRepository repository,
    required PreferencesRepository preferences,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _preferences = preferences,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final TaxRateRepository _repository;
  final PreferencesRepository _preferences;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Archives ([archived] true) or restores the rate [id]. Archiving the
  /// rate that is the default for new products clears that default.
  Future<Result<TaxRate>> call(String id, {required bool archived}) =>
      _transactions.runResult(() async {
        final current = (await _repository.getById(id)).getOrThrow();
        if (current.isArchived == archived) {
          return current;
        }
        if (!archived &&
            (await _repository.nameExists(
              current.name,
              excludingId: id,
            )).getOrThrow()) {
          throw FailureException(
            (FieldErrors()..add(
                  'name',
                  'Another active tax rate has this name. Rename one first.',
                ))
                .toFailure(),
          );
        }
        final now = _clock.now();
        final updated = TaxRate(
          id: current.id,
          name: current.name,
          rateBp: current.rateBp,
          isExempt: current.isExempt,
          createdAt: current.createdAt,
          updatedAt: now,
          archivedAt: archived ? now : null,
        );
        (await _repository.update(updated)).getOrThrow();
        if (archived) {
          final prefs = (await _preferences.load()).getOrThrow();
          if (prefs.defaultTaxRateId == id) {
            (await _preferences.save(prefs.copyWith(clearDefaultTaxRate: true)))
                .getOrThrow();
          }
        }
        (await _audit.record(
          AuditEntry(
            id: _ids.newId(),
            entityType: 'tax_rate',
            entityId: id,
            action: archived ? 'archived' : 'restored',
            summary:
                'Tax rate "${current.name}" '
                '${archived ? 'archived' : 'restored'}.',
            occurredAt: now,
          ),
        )).getOrThrow();
        return updated;
      });
}

/// Chooses (or clears) the tax rate preselected for new products.
final class SetDefaultTaxRate {
  /// Creates the use case.
  const SetDefaultTaxRate({
    required TaxRateRepository taxRates,
    required PreferencesRepository preferences,
    required TransactionRunner transactions,
  }) : _taxRates = taxRates,
       _preferences = preferences,
       _transactions = transactions;

  final TaxRateRepository _taxRates;
  final PreferencesRepository _preferences;
  final TransactionRunner _transactions;

  /// Makes [id] the default; `null` clears it.
  Future<Result<void>> call(String? id) => _transactions.runResult(() async {
    if (id != null) {
      final rate = (await _taxRates.getById(id)).getOrThrow();
      if (rate.isArchived) {
        throw const FailureException(
          ValidationFailure('Archived tax rates cannot be the default.'),
        );
      }
    }
    final prefs = (await _preferences.load()).getOrThrow();
    (await _preferences.save(
      id == null
          ? prefs.copyWith(clearDefaultTaxRate: true)
          : prefs.copyWith(defaultTaxRateId: id),
    )).getOrThrow();
  });
}
