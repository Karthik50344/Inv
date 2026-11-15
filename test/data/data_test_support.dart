import 'package:drift/native.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/features/categories/data/repositories/drift_category_repository.dart';
import 'package:inventrix/features/products/data/repositories/drift_product_repository.dart';
import 'package:inventrix/features/products/data/repositories/drift_unit_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_settings_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_tax_rate_repository.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

final DateTime t0 = DateTime.utc(2026, 1, 1, 10);

/// In-memory database with real Drift repositories.
class DataHarness {
  DataHarness() : db = AppDatabase(NativeDatabase.memory()) {
    settings = DriftSettingsRepository(db);
    taxRates = DriftTaxRateRepository(db);
    categories = DriftCategoryRepository(db);
    units = DriftUnitRepository(db);
    products = DriftProductRepository(db, settings);
  }

  final AppDatabase db;
  late final DriftSettingsRepository settings;
  late final DriftTaxRateRepository taxRates;
  late final DriftCategoryRepository categories;
  late final DriftUnitRepository units;
  late final DriftProductRepository products;

  Future<void> close() => db.close();
}

UnitOfMeasure unit({String id = 'u1', String symbol = 'pcs', int places = 0}) =>
    UnitOfMeasure(
      id: id,
      name: 'Unit $symbol',
      symbol: symbol,
      decimalPlaces: places,
      createdAt: t0,
      updatedAt: t0,
    );

Category category({
  String id = 'c1',
  String name = 'Tools',
  DateTime? archived,
}) => Category(
  id: id,
  name: name,
  createdAt: t0,
  updatedAt: t0,
  archivedAt: archived,
);

Product product({
  String id = 'p1',
  String sku = 'SKU-1',
  String name = 'Hammer',
  String? barcode,
  String unitId = 'u1',
  String? categoryId,
  int sellingMinor = 1000,
  DateTime? archived,
}) => Product(
  id: id,
  sku: sku,
  barcode: barcode,
  name: name,
  unitId: unitId,
  categoryId: categoryId,
  purchasePrice: Money.fromMinor(500, currencyCode: 'INR', decimalPlaces: 2),
  sellingPrice: Money.fromMinor(
    sellingMinor,
    currencyCode: 'INR',
    decimalPlaces: 2,
  ),
  priceIncludesTax: false,
  reorderLevel: const Quantity.fromMilli(5000),
  createdAt: t0,
  updatedAt: t0,
  archivedAt: archived,
);
