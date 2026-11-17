import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/settings/domain/entities/money_lock.dart';
import 'package:inventrix/features/settings/domain/entities/setting_keys.dart';
import 'package:inventrix/features/settings/domain/repositories/currency_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// Stores the currency and reports which amounts depend on it.
final class DriftCurrencyRepository implements CurrencyRepository {
  /// Creates the repository.
  const DriftCurrencyRepository(this._db);

  final AppDatabase _db;

  /// Counts the stored amounts that carry no currency of their own.
  static const String moneyLockSql = '''
SELECT
  (SELECT COUNT(*) FROM products
     WHERE purchase_price_minor <> 0 OR selling_price_minor <> 0) AS products,
  (SELECT COUNT(*) FROM customers WHERE opening_balance_minor <> 0)
    + (SELECT COUNT(*) FROM suppliers WHERE opening_balance_minor <> 0)
    AS balances,
  (SELECT COUNT(*) FROM stock_movements
     WHERE total_cost_minor <> 0 OR unit_cost_minor_snapshot <> 0)
    + (SELECT COUNT(*) FROM inventory_balances
         WHERE inventory_value_minor <> 0) AS stock,
  (SELECT COUNT(*) FROM sales_invoices
     WHERE status = 'posted' AND total_minor <> 0)
    + (SELECT COUNT(*) FROM purchase_invoices
         WHERE status = 'posted' AND total_minor <> 0) AS invoices
''';

  @override
  Future<Result<MoneyLock>> moneyLock() => guardDatabase(() async {
    final row = await _db
        .customSelect(
          moneyLockSql,
          readsFrom: {
            _db.products,
            _db.customers,
            _db.suppliers,
            _db.stockMovements,
            _db.inventoryBalances,
            _db.salesInvoices,
            _db.purchaseInvoices,
          },
        )
        .getSingle();
    return MoneyLock(
      pricedProducts: row.read<int>('products'),
      openingBalances: row.read<int>('balances'),
      stockRecords: row.read<int>('stock'),
      postedInvoices: row.read<int>('invoices'),
    );
  });

  @override
  Future<Result<void>> save(CurrencyConfig config) => guardDatabase(() async {
    final now = toEpochMs(DateTime.now());
    await _db.transaction(() async {
      for (final entry in {
        SettingKeys.currencyCode: config.currencyCode,
        SettingKeys.currencyDecimalPlaces: '${config.decimalPlaces}',
      }.entries) {
        await _db
            .into(_db.appSettings)
            .insertOnConflictUpdate(
              AppSettingsCompanion(
                key: Value(entry.key),
                value: Value(entry.value),
                updatedAt: Value(now),
              ),
            );
      }
    });
  });
}
