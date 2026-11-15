import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';

/// Validates and updates a customer.
///
/// Past documents keep their own snapshots, so edits never change history.
final class UpdateCustomer {
  /// Creates the use case.
  const UpdateCustomer({
    required CustomerRepository repository,
    required SettingsRepository settings,
    required Clock clock,
  }) : _repository = repository,
       _settings = settings,
       _clock = clock;

  final CustomerRepository _repository;
  final SettingsRepository _settings;
  final Clock _clock;

  /// Updates customer [id] from [draft].
  Future<Result<Customer>> call(String id, PartyDraft draft) async {
    final loaded = await _repository.getById(id);
    final existing = loaded.valueOrNull;
    if (existing == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    final currencyResult = await _settings.getCurrencyConfig();
    final currency = currencyResult.valueOrNull;
    if (currency == null) {
      return Result.failure(currencyResult.failureOrNull!);
    }
    final validated = validatePartyDraft(draft, currency);
    final fields = validated.valueOrNull;
    if (fields == null) {
      return Result.failure(validated.failureOrNull!);
    }
    final updated = Customer.fromFields(
      id: existing.id,
      fields: fields,
      createdAt: existing.createdAt,
      updatedAt: _clock.now(),
      archivedAt: existing.archivedAt,
    );
    final saved = await _repository.update(updated);
    return saved.isFailure
        ? Result.failure(saved.failureOrNull!)
        : Result.success(updated);
  }
}
