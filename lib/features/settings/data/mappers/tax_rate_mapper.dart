import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';

/// Row -> entity.
TaxRate taxRateFromRow(TaxRateRow row) => TaxRate(
  id: row.id,
  name: row.name,
  rateBp: row.rateBp,
  isExempt: row.isExempt,
  createdAt: fromEpochMs(row.createdAt),
  updatedAt: fromEpochMs(row.updatedAt),
  archivedAt: fromEpochMsOrNull(row.archivedAt),
);

/// Entity -> insert/update companion.
TaxRatesCompanion taxRateToCompanion(TaxRate rate) => TaxRatesCompanion(
  id: Value(rate.id),
  name: Value(rate.name),
  rateBp: Value(rate.rateBp),
  isExempt: Value(rate.isExempt),
  archivedAt: Value(toEpochMsOrNull(rate.archivedAt)),
  createdAt: Value(toEpochMs(rate.createdAt)),
  updatedAt: Value(toEpochMs(rate.updatedAt)),
);
