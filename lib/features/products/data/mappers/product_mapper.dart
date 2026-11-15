import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Row -> entity. Prices are interpreted in the active [currency].
Product productFromRow(ProductRow row, CurrencyConfig currency) => Product(
  id: row.id,
  sku: row.sku,
  barcode: row.barcode,
  name: row.name,
  description: row.description,
  categoryId: row.categoryId,
  unitId: row.unitId,
  purchasePrice: currency.fromMinor(row.purchasePriceMinor),
  sellingPrice: currency.fromMinor(row.sellingPriceMinor),
  priceIncludesTax: row.priceIncludesTax,
  taxRateId: row.taxRateId,
  reorderLevel: Quantity.fromMilli(row.reorderLevelMilli),
  imagePath: row.imagePath,
  createdAt: fromEpochMs(row.createdAt),
  updatedAt: fromEpochMs(row.updatedAt),
  archivedAt: fromEpochMsOrNull(row.archivedAt),
);

/// Entity -> insert/update companion.
ProductsCompanion productToCompanion(Product product) => ProductsCompanion(
  id: Value(product.id),
  sku: Value(product.sku),
  barcode: Value(product.barcode),
  name: Value(product.name),
  description: Value(product.description),
  categoryId: Value(product.categoryId),
  unitId: Value(product.unitId),
  purchasePriceMinor: Value(product.purchasePrice.minorUnits),
  sellingPriceMinor: Value(product.sellingPrice.minorUnits),
  priceIncludesTax: Value(product.priceIncludesTax),
  taxRateId: Value(product.taxRateId),
  reorderLevelMilli: Value(product.reorderLevel.milli),
  imagePath: Value(product.imagePath),
  archivedAt: Value(toEpochMsOrNull(product.archivedAt)),
  createdAt: Value(toEpochMs(product.createdAt)),
  updatedAt: Value(toEpochMs(product.updatedAt)),
);
