import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';

/// Writes the tax configuration. Records are created and edited but never
/// deleted: they are switched off instead, so every rule that ever applied
/// stays traceable. Posted documents keep their own snapshot either way.
abstract interface class TaxConfigRepository {
  /// Creates or updates a regime.
  Future<Result<void>> saveRegime(TaxRegime regime, DateTime now);

  /// Creates or updates a jurisdiction.
  Future<Result<void>> saveJurisdiction(TaxJurisdiction jurisdiction, DateTime now);

  /// Creates or updates a category.
  Future<Result<void>> saveCategory(TaxCategory category, DateTime now);

  /// Creates or updates a profile. Making a profile the default clears the
  /// flag on the others.
  Future<Result<void>> saveProfile(TaxProfile profile, DateTime now);

  /// Creates or updates an override.
  Future<Result<void>> saveOverride(TaxOverride override, DateTime now);

  /// Creates or updates a rule.
  Future<Result<void>> saveRule(TaxRule rule, DateTime now);

  /// Creates or updates a component.
  Future<Result<void>> saveComponent(TaxComponent component, DateTime now);

  /// Switches a record on or off.
  Future<Result<void>> setActive(
    TaxConfigKind kind,
    String id, {
    required bool active,
    required DateTime now,
  });
}

/// Reads and writes [TaxPreferences].
abstract interface class TaxPreferencesRepository {
  /// The current preferences.
  Future<Result<TaxPreferences>> load();

  /// Saves the preferences.
  Future<Result<void>> save(TaxPreferences preferences, DateTime now);
}
