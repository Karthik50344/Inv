import 'package:drift/drift.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/core/database/schema_extras.dart';
import 'package:inventrix/core/database/tables/tables.dart';

part 'app_database.g.dart';

/// The single Drift/SQLite database for Inventrix
/// (`inventory_management.sqlite`).
@DriftDatabase(
  tables: [
    BusinessProfiles,
    AppSettings,
    Categories,
    Units,
    TaxRates,
    Products,
    InventoryBalances,
    StockMovements,
    Customers,
    Suppliers,
    AuditLogs,
    DocumentSequences,
    PurchaseInvoices,
    PurchaseInvoiceItems,
    SalesInvoices,
    SalesInvoiceItems,
    PaymentMethods,
    Payments,
    PaymentAllocations,
    PaymentReversals,
    SalesReturns,
    SalesReturnItems,
    PurchaseReturns,
    PurchaseReturnItems,
    ExpenseCategories,
    Expenses,
    Attachments,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the database on top of [executor].
  AppDatabase(super.executor);

  /// Current schema version. Increment with every schema change and add a
  /// migration step plus a migration test.
  static const int currentSchemaVersion = 8;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      for (final statement in [
        ...kSchemaExtraStatements,
        ...kSchemaExtraStatementsV2,
        ...kSchemaExtraStatementsV3,
        ...kSchemaExtraStatementsV4,
        ...kSchemaExtraStatementsV5,
        ...kSchemaExtraStatementsV6,
        ...kSchemaExtraStatementsV7,
        ...kSchemaExtraStatementsV8,
      ]) {
        await customStatement(statement);
      }
      await _seedPaymentMethods();
      await _seedExpenseCategories();
      await _seedDefaultSettings();
    },
    onUpgrade: (migrator, from, to) async {
      // Stepwise, additive migrations only; destructive changes must copy
      // and verify data first.
      if (from < 2) {
        await migrator.createTable(customers);
        await migrator.createTable(suppliers);
        for (final statement in kSchemaExtraStatementsV2) {
          await customStatement(statement);
        }
      }
      if (from < 3) {
        await migrator.createTable(auditLogs);
        for (final statement in kSchemaExtraStatementsV3) {
          await customStatement(statement);
        }
      }
      if (from < 4) {
        await migrator.createTable(documentSequences);
        await migrator.createTable(purchaseInvoices);
        await migrator.createTable(purchaseInvoiceItems);
        for (final statement in kSchemaExtraStatementsV4) {
          await customStatement(statement);
        }
      }
      if (from < 5) {
        await migrator.createTable(salesInvoices);
        await migrator.createTable(salesInvoiceItems);
        for (final statement in kSchemaExtraStatementsV5) {
          await customStatement(statement);
        }
      }
      if (from < 6) {
        await migrator.createTable(paymentMethods);
        await migrator.createTable(payments);
        await migrator.createTable(paymentAllocations);
        await migrator.createTable(paymentReversals);
        for (final statement in kSchemaExtraStatementsV6) {
          await customStatement(statement);
        }
        await _seedPaymentMethods();
      }
      if (from < 7) {
        await migrator.createTable(salesReturns);
        await migrator.createTable(salesReturnItems);
        await migrator.createTable(purchaseReturns);
        await migrator.createTable(purchaseReturnItems);
        for (final statement in kSchemaExtraStatementsV7) {
          await customStatement(statement);
        }
      }
      if (from < 8) {
        await migrator.createTable(expenseCategories);
        await migrator.createTable(expenses);
        await migrator.createTable(attachments);
        for (final statement in kSchemaExtraStatementsV8) {
          await customStatement(statement);
        }
        await _seedExpenseCategories();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (details.hadUpgrade) {
        final violations = await customSelect('PRAGMA foreign_key_check').get();
        if (violations.isNotEmpty) {
          throw StateError(
            'Foreign key violations found after migration: '
            '${violations.length}',
          );
        }
      }
    },
  );

  /// Forces the connection open so migrations run during app start.
  Future<void> initialize() async {
    await customSelect('SELECT 1').get();
  }

  /// Whether SQLite is enforcing foreign keys on this connection.
  Future<bool> isForeignKeyEnforcementEnabled() async {
    final row = await customSelect('PRAGMA foreign_keys').getSingle();
    return row.read<int>('foreign_keys') == 1;
  }

  /// Runs `PRAGMA integrity_check`; a healthy database returns `['ok']`.
  Future<List<String>> integrityCheck() async {
    final rows = await customSelect('PRAGMA integrity_check').get();
    return rows.map((row) => row.read<String>('integrity_check')).toList();
  }

  /// Starter payment methods. Fixed ids and `INSERT OR IGNORE` make this safe
  /// to run on both fresh installs and the 5 -> 6 upgrade.
  Future<void> _seedPaymentMethods() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    const defaults = {
      'pm-cash': 'Cash',
      'pm-bank': 'Bank transfer',
      'pm-card': 'Card',
      'pm-other': 'Other',
    };
    for (final entry in defaults.entries) {
      await customStatement(
        'INSERT OR IGNORE INTO payment_methods (id, name, created_at) '
        'VALUES (?, ?, ?)',
        [entry.key, entry.value, now],
      );
    }
  }

  /// Starter expense categories. Fixed ids and `INSERT OR IGNORE` make this
  /// safe to run on both fresh installs and the 7 -> 8 upgrade.
  Future<void> _seedExpenseCategories() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    const defaults = {
      'ec-rent': 'Rent',
      'ec-utilities': 'Utilities',
      'ec-salaries': 'Salaries and wages',
      'ec-transport': 'Transport',
      'ec-supplies': 'Office supplies',
      'ec-maintenance': 'Repairs and maintenance',
      'ec-marketing': 'Marketing',
      'ec-other': 'Other',
    };
    for (final entry in defaults.entries) {
      await customStatement(
        'INSERT OR IGNORE INTO expense_categories '
        '(id, name, created_at, updated_at) VALUES (?, ?, ?, ?)',
        [entry.key, entry.value, now, now],
      );
    }
  }

  Future<void> _seedDefaultSettings() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final defaults = <String, String>{
      'currency_code': AppConstants.defaultCurrencyCode,
      'currency_decimal_places': AppConstants.defaultCurrencyDecimalPlaces
          .toString(),
      'locale': AppConstants.defaultLocale,
      'theme_mode': 'system',
    };
    for (final entry in defaults.entries) {
      await customStatement(
        'INSERT INTO app_settings (key, value, updated_at) VALUES (?, ?, ?)',
        [entry.key, entry.value, now],
      );
    }
  }
}
