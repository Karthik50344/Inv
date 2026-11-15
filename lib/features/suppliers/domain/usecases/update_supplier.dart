import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';

/// Validates and updates a supplier.
///
/// Past documents keep their own snapshots, so edits never change history.
final class UpdateSupplier {
  /// Creates the use case.
  const UpdateSupplier({
    required SupplierRepository repository,
    required SettingsRepository settings,
    required Clock clock,
  }) : _repository = repository,
       _settings = settings,
       _clock = clock;

  final SupplierRepository _repository;
  final SettingsRepository _settings;
  final Clock _clock;

  /// Updates supplier [id] from [draft].
  Future<Result<Supplier>> call(String id, PartyDraft draft) async {
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
    final updated = Supplier.fromFields(
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
