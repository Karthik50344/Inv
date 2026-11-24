import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_context.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_repository.dart';

/// Drift implementation of [TaxRepository].
final class DriftTaxRepository implements TaxRepository {
  /// Creates the repository.
  const DriftTaxRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<TaxContext?>> loadContext() => guardDatabase(() async {
    final profile =
        await (_db.select(_db.taxProfiles)
              ..where((t) => t.isDefault.equals(true) & t.isActive.equals(true))
              ..limit(1))
            .getSingleOrNull();
    if (profile == null) {
      return null;
    }
    final regime = await (_db.select(
      _db.taxRegimes,
    )..where((t) => t.id.equals(profile.regimeId))).getSingleOrNull();
    final settings = await _db
        .customSelect(
          'SELECT key, value FROM app_settings WHERE key IN '
          "('tax_country_code', 'tax_region_code', 'tax_seller_registered')",
        )
        .get();
    final values = {
      for (final r in settings) r.read<String>('key'): r.read<String>('value'),
    };
    final regimeCountry = regime?.countryCode ?? 'ZZ';
    final country =
        values['tax_country_code'] ??
        (regimeCountry == 'XX' ? 'ZZ' : regimeCountry);
    final region = values['tax_region_code'];
    return TaxContext(
      taxProfileId: profile.id,
      sellerLocation: TaxLocation(
        countryCode: country,
        regionCode: (region == null || region.isEmpty) ? null : region,
      ),
      isSellerTaxRegistered: values['tax_seller_registered'] != 'false',
    );
  });

  @override
  Future<Result<TaxConfiguration>> loadConfiguration() => guardDatabase(
    () async {
      final regimes = await _db.select(_db.taxRegimes).get();
      final jurisdictions = await _db.select(_db.taxJurisdictions).get();
      final categories = await _db.select(_db.taxCategories).get();
      final profiles = await _db.select(_db.taxProfiles).get();
      final overrides = await _db.select(_db.taxOverrides).get();
      final rules = await _db.select(_db.taxRules).get();
      final components = await _db.select(_db.taxComponents).get();
      return TaxConfiguration(
        regimes: [
          for (final r in regimes)
            TaxRegime(
              id: r.id,
              name: r.name,
              countryCode: r.countryCode,
              currencyCode: r.currencyCode,
              description: r.description,
              isActive: r.isActive,
            ),
        ],
        jurisdictions: [
          for (final j in jurisdictions)
            TaxJurisdiction(
              id: j.id,
              regimeId: j.regimeId,
              countryCode: j.countryCode,
              regionCode: j.regionCode,
              regionName: j.regionName,
              jurisdictionType: JurisdictionType(j.jurisdictionType),
              parentJurisdictionId: j.parentJurisdictionId,
              isActive: j.isActive,
            ),
        ],
        categories: [
          for (final c in categories)
            TaxCategory(
              id: c.id,
              name: c.name,
              code: c.code,
              description: c.description,
              // The CHECK constraint guarantees a known code.
              defaultTaxTreatment: TaxTreatment.tryParse(
                c.defaultTaxTreatment,
              )!,
              isActive: c.isActive,
            ),
        ],
        profiles: [
          for (final p in profiles)
            TaxProfile(
              id: p.id,
              name: p.name,
              regimeId: p.regimeId,
              description: p.description,
              isDefault: p.isDefault,
              defaultTaxCategoryId: p.defaultTaxCategoryId,
              isActive: p.isActive,
            ),
        ],
        overrides: [
          for (final o in overrides)
            TaxOverride(
              id: o.id,
              name: o.name,
              taxCategoryId: o.taxCategoryId,
              reason: o.reason,
              isActive: o.isActive,
            ),
        ],
        rules: [
          for (final r in rules)
            TaxRule(
              id: r.id,
              taxProfileId: r.taxProfileId,
              taxCategoryId: r.taxCategoryId,
              jurisdictionId: r.jurisdictionId,
              transactionType: TaxTransactionType.tryParse(r.transactionType),
              customerTaxStatus: r.customerTaxStatus,
              supplyType: r.supplyType,
              supplyRelation: SupplyRelation.parse(r.supplyRelation),
              calculationMethod: TaxCalculationMethod.tryParse(
                r.calculationMethod,
              )!,
              isStackable: r.isStackable,
              effectiveFrom: fromEpochMs(r.effectiveFrom),
              effectiveUntil: fromEpochMsOrNull(r.effectiveUntil),
              priority: r.priority,
              isActive: r.isActive,
            ),
        ],
        components: [
          for (final c in components)
            TaxComponent(
              id: c.id,
              taxRuleId: c.taxRuleId,
              name: c.name,
              componentType: TaxComponentType(c.componentType),
              rateBasisPoints: c.rateBasisPoints,
              fixedAmountMinor: c.fixedAmountMinor,
              calculationOrder: c.calculationOrder,
              isCompound: c.isCompound,
              isRecoverable: c.isRecoverable,
              isActive: c.isActive,
            ),
        ],
      );
    },
  );
}
