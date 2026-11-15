import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/inventory/data/mappers/inventory_mapper.dart';
import 'package:inventrix/features/inventory/domain/entities/inventory_valuation.dart';
import 'package:inventrix/features/inventory/domain/entities/reconciliation.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_item.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_position.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Drift implementation of [InventoryRepository].
///
/// Product data comes through the [ProductRepository] contract (never from
/// the products feature's data layer).
final class DriftInventoryRepository implements InventoryRepository {
  /// Creates the repository.
  const DriftInventoryRepository(this._db, this._settings, this._products);

  final AppDatabase _db;
  final SettingsRepository _settings;
  final ProductRepository _products;

  @override
  Future<Result<List<StockItem>>> listStock(StockFilter filter) =>
      guardDatabase(() async {
        final currency = await _currency();
        final products = (await _products.search(
          ProductFilter(
            query: filter.query,
            categoryId: filter.categoryId,
            includeArchived: filter.includeArchived,
          ),
        )).getOrThrow();
        final balances = await _balanceMap(currency);
        return [
          for (final product in products)
            StockItem(
              product: product,
              balance:
                  balances[product.id] ?? emptyBalance(product.id, currency),
            ),
        ].where((item) => filter.status.matches(item.status)).toList();
      });

  @override
  Future<Result<StockItem>> getStockItem(String productId) =>
      guardDatabase(() async {
        final currency = await _currency();
        final product = (await _products.getById(productId)).getOrThrow();
        final balance = await _balanceOf(productId, currency);
        return StockItem(product: product, balance: balance);
      });

  @override
  Future<Result<StockBalance>> getBalance(String productId) =>
      guardDatabase(() async => _balanceOf(productId, await _currency()));

  @override
  Future<Result<List<StockBalance>>> allBalances() => guardDatabase(
    () async => (await _balanceMap(await _currency())).values.toList(),
  );

  @override
  Future<Result<List<StockMovement>>> movements(
    String productId, {
    int limit = 50,
    int offset = 0,
  }) => guardDatabase(() async {
    final currency = await _currency();
    final query = _db.select(_db.stockMovements)
      ..where((t) => t.productId.equals(productId))
      ..orderBy([
        (t) => OrderingTerm.desc(t.occurredAt),
        (t) => OrderingTerm(
          expression: const CustomExpression<int>('rowid'),
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(limit, offset: offset);
    return (await query.get())
        .map((row) => movementFromRow(row, currency))
        .toList();
  });

  @override
  Future<Result<List<StockMovement>>> movementsForSource(
    String sourceType,
    String sourceId,
  ) => guardDatabase(() async {
    final currency = await _currency();
    final query = _db.select(_db.stockMovements)
      ..where(
        (t) => t.sourceType.equals(sourceType) & t.sourceId.equals(sourceId),
      )
      ..orderBy([
        (t) => OrderingTerm.asc(t.occurredAt),
        (t) => OrderingTerm(
          expression: const CustomExpression<int>('rowid'),
        ),
      ]);
    return (await query.get())
        .map((row) => movementFromRow(row, currency))
        .toList();
  });

  @override
  Future<Result<bool>> hasMovements(String productId) =>
      guardDatabase(() async {
        final count = _db.stockMovements.id.count();
        final query = _db.selectOnly(_db.stockMovements)
          ..addColumns([count])
          ..where(_db.stockMovements.productId.equals(productId));
        final row = await query.getSingle();
        return (row.read(count) ?? 0) > 0;
      });

  @override
  Future<Result<List<LedgerTotals>>> ledgerTotals() => guardDatabase(() async {
    final currency = await _currency();
    final rows = await _db
        .customSelect(
          'SELECT product_id, SUM(quantity_delta_milli) AS qty, '
          'SUM(total_cost_minor) AS cost '
          'FROM stock_movements GROUP BY product_id',
        )
        .get();
    return [
      for (final row in rows)
        LedgerTotals(
          productId: row.read<String>('product_id'),
          quantity: Quantity.fromMilli(row.read<int>('qty')),
          value: currency.fromMinor(row.read<int>('cost')),
        ),
    ];
  });

  @override
  Future<Result<InventoryValuation>> valuation() => guardDatabase(() async {
    final currency = await _currency();
    final items = (await listStock(
      const StockFilter(includeArchived: true),
    )).getOrThrow();
    var total = currency.zero();
    var inStock = 0;
    var low = 0;
    var out = 0;
    for (final item in items) {
      total += item.balance.inventoryValue;
      if (item.balance.quantityOnHand.isPositive) {
        inStock++;
      }
      if (!item.product.isArchived) {
        if (item.status == StockStatus.low) {
          low++;
        } else if (item.status == StockStatus.out) {
          out++;
        }
      }
    }
    return InventoryValuation(
      totalValue: total,
      productsInStock: inStock,
      lowStockCount: low,
      outOfStockCount: out,
    );
  });

  @override
  Future<Result<void>> applyMovement(
    StockMovement movement,
    StockPosition newPosition,
  ) => guardDatabase(() async {
    await _db.into(_db.stockMovements).insert(movementToCompanion(movement));
    await _upsertBalance(movement.productId, newPosition, movement.createdAt);
  });

  @override
  Future<Result<void>> replaceBalance(
    String productId,
    StockPosition position,
    DateTime at,
  ) => guardDatabase(() => _upsertBalance(productId, position, at));

  Future<void> _upsertBalance(
    String productId,
    StockPosition position,
    DateTime at,
  ) async {
    await _db
        .into(_db.inventoryBalances)
        .insertOnConflictUpdate(
          InventoryBalancesCompanion(
            productId: Value(productId),
            quantityOnHandMilli: Value(position.quantity.milli),
            inventoryValueMinor: Value(position.value.minorUnits),
            updatedAt: Value(toEpochMs(at)),
          ),
        );
  }

  Future<StockBalance> _balanceOf(
    String productId,
    CurrencyConfig currency,
  ) async {
    final row = await (_db.select(
      _db.inventoryBalances,
    )..where((t) => t.productId.equals(productId))).getSingleOrNull();
    return row == null
        ? emptyBalance(productId, currency)
        : balanceFromRow(row, currency);
  }

  Future<Map<String, StockBalance>> _balanceMap(CurrencyConfig currency) async {
    final rows = await _db.select(_db.inventoryBalances).get();
    return {
      for (final row in rows) row.productId: balanceFromRow(row, currency),
    };
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
