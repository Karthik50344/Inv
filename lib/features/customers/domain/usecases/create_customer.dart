import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';

/// Validates and creates a customer.
final class CreateCustomer {
  /// Creates the use case.
  const CreateCustomer({
    required CustomerRepository repository,
    required SettingsRepository settings,
    required IdGenerator ids,
    required Clock clock,
  }) : _repository = repository,
       _settings = settings,
       _ids = ids,
       _clock = clock;

  final CustomerRepository _repository;
  final SettingsRepository _settings;
  final IdGenerator _ids;
  final Clock _clock;

  /// Creates a customer from [draft].
  Future<Result<Customer>> call(PartyDraft draft) async {
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
    final now = _clock.now();
    final customer = Customer.fromFields(
      id: _ids.newId(),
      fields: fields,
      createdAt: now,
      updatedAt: now,
    );
    final saved = await _repository.create(customer);
    return saved.isFailure
        ? Result.failure(saved.failureOrNull!)
        : Result.success(customer);
  }
}
