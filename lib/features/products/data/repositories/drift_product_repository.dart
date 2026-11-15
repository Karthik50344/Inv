import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/products/data/mappers/product_mapper.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// Drift implementation of [ProductRepository].
final class DriftProductRepository implements ProductRepository {
  /// Creates the repository.
  const DriftProductRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  @override
  Future<Result<List<Product>>> search(ProductFilter filter) =>
      guardDatabase(() async {
        final currency = await _currency();
        final text = filter.query.trim();
        final select = _db.select(_db.products)
          ..where((t) {
            Expression<bool> predicate = const Constant(true);
            if (!filter.includeArchived) {
              predicate = predicate & t.archivedAt.isNull();
            }
            if (filter.categoryId != null) {
              predicate = predicate & t.categoryId.equals(filter.categoryId!);
            }
            if (text.isNotEmpty) {
              predicate =
                  predicate &
                  (t.name.contains(text) |
                      t.sku.contains(text) |
                      t.barcode.contains(text));
            }
            return predicate;
          })
          ..orderBy([(t) => OrderingTerm.asc(t.name)]);
        return (await select.get())
            .map((row) => productFromRow(row, currency))
            .toList();
      });

  @override
  Future<Result<Product>> getById(String id) => guardDatabase(() async {
    final currency = await _currency();
    final row = await (_db.select(
      _db.products,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('Product not found.'));
    }
    return productFromRow(row, currency);
  });

  @override
  Future<Result<bool>> skuExists(String sku, {String? excludeId}) =>
      guardDatabase(() async {
        final products = _db.products;
        Expression<bool> predicate = products.sku.equals(sku);
        if (excludeId != null) {
          predicate = predicate & products.id.equals(excludeId).not();
        }
        return _exists(predicate);
      });

  @override
  Future<Result<bool>> barcodeExists(String barcode, {String? excludeId}) =>
      guardDatabase(() async {
        final products = _db.products;
        Expression<bool> predicate = products.barcode.equals(barcode);
        if (excludeId != null) {
          predicate = predicate & products.id.equals(excludeId).not();
        }
        return _exists(predicate);
      });

  @override
  Future<Result<int>> nextAutoSkuNumber() => guardDatabase(() async {
    final row = await _db
        .customSelect(
          'SELECT MAX(CAST(SUBSTR(sku, 3) AS INTEGER)) AS max_number '
          'FROM products '
          "WHERE sku GLOB 'P-[0-9]*' AND sku NOT GLOB 'P-*[^0-9]*'",
        )
        .getSingle();
    return (row.readNullable<int>('max_number') ?? 0) + 1;
  });

  @override
  Future<Result<void>> create(Product product) => guardDatabase(
    () => _db.transaction(() async {
      await _db.into(_db.products).insert(productToCompanion(product));
      // Every product has exactly one balance row from day one.
      await _db
          .into(_db.inventoryBalances)
          .insert(
            InventoryBalancesCompanion(
              productId: Value(product.id),
              quantityOnHandMilli: const Value(0),
              inventoryValueMinor: const Value(0),
              updatedAt: Value(toEpochMs(product.createdAt)),
            ),
          );
    }),
  );

  @override
  Future<Result<void>> update(Product product) => guardDatabase(() async {
    final affected =
        await (_db.update(_db.products)..where((t) => t.id.equals(product.id)))
            .write(productToCompanion(product));
    if (affected == 0) {
      throw const FailureException(NotFoundFailure('Product not found.'));
    }
  });

  Future<bool> _exists(Expression<bool> predicate) async {
    final count = _db.products.id.count();
    final query = _db.selectOnly(_db.products)
      ..addColumns([count])
      ..where(predicate);
    final row = await query.getSingle();
    return (row.read(count) ?? 0) > 0;
  }

  Future<CurrencyConfig> _currency() async {
    final result = await _settings.getCurrencyConfig();
    final config = result.valueOrNull;
    if (config == null) {
      throw FailureException(result.failureOrNull!);
    }
    return config;
  }
}
