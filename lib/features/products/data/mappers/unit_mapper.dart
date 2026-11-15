import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';

/// Row -> entity.
UnitOfMeasure unitFromRow(UnitRow row) => UnitOfMeasure(
  id: row.id,
  name: row.name,
  symbol: row.symbol,
  decimalPlaces: row.decimalPlaces,
  createdAt: fromEpochMs(row.createdAt),
  updatedAt: fromEpochMs(row.updatedAt),
  archivedAt: fromEpochMsOrNull(row.archivedAt),
);

/// Entity -> insert/update companion.
UnitsCompanion unitToCompanion(UnitOfMeasure unit) => UnitsCompanion(
  id: Value(unit.id),
  name: Value(unit.name),
  symbol: Value(unit.symbol),
  decimalPlaces: Value(unit.decimalPlaces),
  archivedAt: Value(toEpochMsOrNull(unit.archivedAt)),
  createdAt: Value(toEpochMs(unit.createdAt)),
  updatedAt: Value(toEpochMs(unit.updatedAt)),
);
