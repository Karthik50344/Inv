import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/features/settings/domain/repositories/currency_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

final RegExp _currencyCode = RegExp(r'^[A-Z]{3}$');

/// Changes the currency and its decimal places, but only while no stored
/// amount would change meaning.
///
/// Invoices, payments, returns and expenses keep their own currency, so they
/// stay correct. Product prices, opening balances and stock costs are plain
/// numbers in the active currency; while any exists the change is refused
/// (see `MoneyLock`). The check and the save happen in one transaction.
final class ChangeCurrency {
  /// Creates the use case.
  const ChangeCurrency({
    required CurrencyRepository currencies,
    required SettingsRepository settings,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _currencies = currencies,
       _settings = settings,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final CurrencyRepository _currencies;
  final SettingsRepository _settings;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Sets the currency to [code] with [decimalPlaces] digits (0-4).
  Future<Result<CurrencyConfig>> call({
    required String code,
    required int decimalPlaces,
  }) async {
    final normalized = code.trim().toUpperCase();
    final errors = FieldErrors();
    if (!_currencyCode.hasMatch(normalized)) {
      errors.add('code', 'Enter a three-letter currency code, e.g. INR.');
    }
    if (decimalPlaces < 0 || decimalPlaces > 4) {
      errors.add('decimalPlaces', 'Use between 0 and 4 decimal places.');
    }
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final wanted = CurrencyConfig(
      currencyCode: normalized,
      decimalPlaces: decimalPlaces,
    );
    return _transactions.runResult(() async {
      final current = (await _settings.getCurrencyConfig()).getOrThrow();
      if (current == wanted) {
        return current;
      }
      final lock = (await _currencies.moneyLock()).getOrThrow();
      if (lock.isLocked) {
        throw FailureException(
          ValidationFailure(
            'The currency cannot be changed because ${lock.reason}. '
            'Those amounts would be read in the new currency. Choose the '
            'currency before adding prices, opening balances or stock.',
          ),
        );
      }
      (await _currencies.save(wanted)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: 'settings',
          entityId: 'currency',
          action: 'changed',
          summary:
              'Currency changed from ${current.currencyCode} '
              '(${current.decimalPlaces} decimals) to '
              '${wanted.currencyCode} (${wanted.decimalPlaces} decimals).',
          occurredAt: _clock.now(),
        ),
      )).getOrThrow();
      return wanted;
    });
  }
}
