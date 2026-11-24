import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_config_repository.dart';

/// Drift implementation of [TaxConfigRepository]. Saves create the record
/// when it does not exist and update it otherwise (the creation time is
/// kept).
final class DriftTaxConfigRepository implements TaxConfigRepository {
  /// Creates the repository.
  const DriftTaxConfigRepository(this._db);

  final AppDatabase _db;

  /// Calendar days are stored as UTC midnight epoch milliseconds.
  static int _day(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch;

  @override
  Future<Result<void>> saveRegime(TaxRegime r, DateTime now) => guardDatabase(
    () => _db.transaction(() async {
      final stamp = toEpochMs(now);
      final update = TaxRegimesCompanion(
          id: Value(r.id),
          name: Value(r.name.trim()),
          countryCode: Value(r.countryCode),
          description: Value(r.description),
          currencyCode: Value(r.currencyCode),
          isActive: Value(r.isActive),
          updatedAt: Value(stamp),
      );
      await _db.into(_db.taxRegimes).insert(
        update.copyWith(createdAt: Value(stamp)),
        onConflict: DoUpdate((_) => update, target: [_db.taxRegimes.id]),
      );
    }),
  );

  @override
  Future<Result<void>> saveJurisdiction(TaxJurisdiction j, DateTime now) =>
      guardDatabase(
        () => _db.transaction(() async {
          final stamp = toEpochMs(now);
          final update = TaxJurisdictionsCompanion(
              id: Value(j.id),
              regimeId: Value(j.regimeId),
              countryCode: Value(j.countryCode),
              regionCode: Value(j.regionCode),
              regionName: Value(j.regionName),
              jurisdictionType: Value(j.jurisdictionType.code),
              parentJurisdictionId: Value(j.parentJurisdictionId),
              isActive: Value(j.isActive),
              updatedAt: Value(stamp),
          );
          await _db.into(_db.taxJurisdictions).insert(
            update.copyWith(createdAt: Value(stamp)),
            onConflict: DoUpdate((_) => update, target: [_db.taxJurisdictions.id]),
          );
        }),
      );

  @override
  Future<Result<void>> saveCategory(TaxCategory c, DateTime now) =>
      guardDatabase(
        () => _db.transaction(() async {
          final stamp = toEpochMs(now);
          final update = TaxCategoriesCompanion(
              id: Value(c.id),
              name: Value(c.name.trim()),
              code: Value(c.code.trim()),
              description: Value(c.description),
              defaultTaxTreatment: Value(c.defaultTaxTreatment.code),
              isActive: Value(c.isActive),
              updatedAt: Value(stamp),
          );
          await _db.into(_db.taxCategories).insert(
            update.copyWith(createdAt: Value(stamp)),
            onConflict: DoUpdate((_) => update, target: [_db.taxCategories.id]),
          );
        }),
      );

  @override
  Future<Result<void>> saveProfile(TaxProfile p, DateTime now) => guardDatabase(
    () => _db.transaction(() async {
      final stamp = toEpochMs(now);
      if (p.isDefault) {
        await _db.customStatement(
          'UPDATE tax_profiles SET is_default = 0 WHERE id <> ?',
          [p.id],
        );
      }
      final update = TaxProfilesCompanion(
          id: Value(p.id),
          name: Value(p.name.trim()),
          regimeId: Value(p.regimeId),
          description: Value(p.description),
          isDefault: Value(p.isDefault),
          defaultTaxCategoryId: Value(p.defaultTaxCategoryId),
          isActive: Value(p.isActive),
          updatedAt: Value(stamp),
      );
      await _db.into(_db.taxProfiles).insert(
        update.copyWith(createdAt: Value(stamp)),
        onConflict: DoUpdate((_) => update, target: [_db.taxProfiles.id]),
      );
    }),
  );

  @override
  Future<Result<void>> saveOverride(TaxOverride o, DateTime now) =>
      guardDatabase(
        () => _db.transaction(() async {
          final stamp = toEpochMs(now);
          final update = TaxOverridesCompanion(
              id: Value(o.id),
              name: Value(o.name.trim()),
              taxCategoryId: Value(o.taxCategoryId),
              reason: Value(o.reason.trim()),
              isActive: Value(o.isActive),
              updatedAt: Value(stamp),
          );
          await _db.into(_db.taxOverrides).insert(
            update.copyWith(createdAt: Value(stamp)),
            onConflict: DoUpdate((_) => update, target: [_db.taxOverrides.id]),
          );
        }),
      );

  @override
  Future<Result<void>> saveRule(TaxRule r, DateTime now) => guardDatabase(
    () => _db.transaction(() async {
      final exists = await _exists('tax_rules', r.id);
      final stamp = toEpochMs(now);
      if (exists) {
        // A rule never moves to another profile or category (a database
        // trigger enforces it); only its conditions change.
        await _db.customStatement(
          'UPDATE tax_rules SET jurisdiction_id = ?, transaction_type = ?, '
          'customer_tax_status = ?, supply_type = ?, supply_relation = ?, '
          'calculation_method = ?, is_stackable = ?, effective_from = ?, '
          'effective_until = ?, priority = ?, is_active = ?, updated_at = ? '
          'WHERE id = ?',
          [
            r.jurisdictionId,
            r.transactionType?.code,
            r.customerTaxStatus,
            r.supplyType,
            r.supplyRelation.code,
            r.calculationMethod.code,
            r.isStackable ? 1 : 0,
            _day(r.effectiveFrom),
            r.effectiveUntil == null ? null : _day(r.effectiveUntil!),
            r.priority,
            r.isActive ? 1 : 0,
            stamp,
            r.id,
          ],
        );
        return;
      }
      await _db.into(_db.taxRules).insert(
        TaxRulesCompanion(
          id: Value(r.id),
          taxProfileId: Value(r.taxProfileId),
          taxCategoryId: Value(r.taxCategoryId),
          jurisdictionId: Value(r.jurisdictionId),
          transactionType: Value(r.transactionType?.code),
          customerTaxStatus: Value(r.customerTaxStatus),
          supplyType: Value(r.supplyType),
          supplyRelation: Value(r.supplyRelation.code),
          calculationMethod: Value(r.calculationMethod.code),
          isStackable: Value(r.isStackable),
          effectiveFrom: Value(_day(r.effectiveFrom)),
          effectiveUntil: Value(r.effectiveUntil == null ? null : _day(r.effectiveUntil!)),
          priority: Value(r.priority),
          isActive: Value(r.isActive),
          createdAt: Value(stamp),
          updatedAt: Value(stamp),
        ),
      );
    }),
  );

  @override
  Future<Result<void>> saveComponent(TaxComponent c, DateTime now) =>
      guardDatabase(
        () => _db.transaction(() async {
          final stamp = toEpochMs(now);
          final update = TaxComponentsCompanion(
              id: Value(c.id),
              taxRuleId: Value(c.taxRuleId),
              name: Value(c.name.trim()),
              componentType: Value(c.componentType.code),
              rateBasisPoints: Value(c.rateBasisPoints),
              fixedAmountMinor: Value(c.fixedAmountMinor),
              calculationOrder: Value(c.calculationOrder),
              isCompound: Value(c.isCompound),
              isRecoverable: Value(c.isRecoverable),
              isActive: Value(c.isActive),
              updatedAt: Value(stamp),
          );
          await _db.into(_db.taxComponents).insert(
            update.copyWith(createdAt: Value(stamp)),
            onConflict: DoUpdate((_) => update, target: [_db.taxComponents.id]),
          );
        }),
      );

  @override
  Future<Result<void>> setActive(
    TaxConfigKind kind,
    String id, {
    required bool active,
    required DateTime now,
  }) => guardDatabase(
    () async => _db.customStatement(
      'UPDATE ${kind.table} SET is_active = ?, updated_at = ? WHERE id = ?',
      [active ? 1 : 0, toEpochMs(now), id],
    ),
  );

  Future<bool> _exists(String table, String id) async {
    final row = await _db
        .customSelect('SELECT 1 AS x FROM $table WHERE id = ?', variables: [Variable<String>(id)])
        .getSingleOrNull();
    return row != null;
  }
}

/// Stores [TaxPreferences] in the app settings.
final class DriftTaxPreferencesRepository implements TaxPreferencesRepository {
  /// Creates the repository.
  const DriftTaxPreferencesRepository(this._db);

  final AppDatabase _db;

  static const _country = 'tax_country_code';
  static const _region = 'tax_region_code';
  static const _registered = 'tax_seller_registered';

  @override
  Future<Result<TaxPreferences>> load() => guardDatabase(() async {
    final rows = await _db
        .customSelect(
          'SELECT key, value FROM app_settings WHERE key IN (?, ?, ?)',
          variables: [
            Variable<String>(_country),
            Variable<String>(_region),
            Variable<String>(_registered),
          ],
        )
        .get();
    final values = {for (final r in rows) r.read<String>('key'): r.read<String>('value')};
    String? text(String key) {
      final v = values[key];
      return v == null || v.isEmpty ? null : v;
    }

    return TaxPreferences(
      countryCode: text(_country),
      regionCode: text(_region),
      sellerRegistered: values[_registered] != 'false',
    );
  });

  @override
  Future<Result<void>> save(TaxPreferences p, DateTime now) => guardDatabase(
    () => _db.transaction(() async {
      Future<void> put(String key, String? value) async {
        if (value == null || value.isEmpty) {
          await _db.customStatement('DELETE FROM app_settings WHERE key = ?', [key]);
          return;
        }
        await _db.customStatement(
          'INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?) '
          'ON CONFLICT(key) DO UPDATE SET value = excluded.value, '
          'updated_at = excluded.updated_at',
          [key, value, toEpochMs(now)],
        );
      }

      await put(_country, p.countryCode);
      await put(_region, p.regionCode);
      await put(_registered, p.sellerRegistered ? 'true' : 'false');
    }),
  );
}
