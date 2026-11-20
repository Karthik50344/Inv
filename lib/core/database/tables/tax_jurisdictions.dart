import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/tax_regimes.dart';

/// A place taxes can differ by (country, state, province, county, city).
@DataClassName('TaxJurisdictionRow')
@TableIndex(name: 'idx_tax_jurisdictions_regime', columns: {#regimeId})
class TaxJurisdictions extends Table {
  TextColumn get id => text()();
  TextColumn get regimeId =>
      text().references(TaxRegimes, #id, onDelete: KeyAction.restrict)();
  TextColumn get countryCode => text()();
  TextColumn get regionCode => text().nullable()();
  TextColumn get regionName => text().nullable()();
  TextColumn get jurisdictionType => text()();
  TextColumn get parentJurisdictionId => text().nullable().references(
    TaxJurisdictions,
    #id,
    onDelete: KeyAction.restrict,
  )();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
