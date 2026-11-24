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
    TaxRegimes,
    TaxJurisdictions,
    TaxCategories,
    TaxProfiles,
    TaxOverrides,
    TaxRules,
    TaxComponents,
    ProductClassifications,
    InvoiceItemTaxComponents,
    AuditEvents,
    AuditOutbox,
    AuditExportHistory,
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
    BackupHistory,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Creates the database on top of [executor].
  AppDatabase(super.executor);

  /// Current schema version. Increment with every schema change and add a
  /// migration step plus a migration test.
  static const int currentSchemaVersion = 13;

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
        ...kSchemaExtraStatementsV9,
        ...kSchemaExtraStatementsV10,
        ...kSchemaExtraStatementsV11,
        ...kSchemaExtraStatementsV12,
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
      if (from < 9) {
        await migrator.createTable(backupHistory);
        for (final statement in kSchemaExtraStatementsV9) {
          await customStatement(statement);
        }
      }
      if (from < 10) {
        await migrator.createTable(taxRegimes);
        await migrator.createTable(taxJurisdictions);
        await migrator.createTable(taxCategories);
        await migrator.createTable(taxProfiles);
        await migrator.createTable(taxOverrides);
        await migrator.createTable(taxRules);
        await migrator.createTable(taxComponents);
        // Idempotent: a simulated older file may already have the columns.
        if (!await _hasColumn('products', 'tax_category_id')) {
          await migrator.addColumn(products, products.taxCategoryId);
        }
        if (!await _hasColumn('products', 'tax_override_id')) {
          await migrator.addColumn(products, products.taxOverrideId);
        }
        for (final statement in kSchemaExtraStatementsV10) {
          await customStatement(statement);
        }
        await _carryOverLegacyTaxRates();
      }
      if (from < 11) {
        await migrator.createTable(productClassifications);
        await migrator.createTable(invoiceItemTaxComponents);
        await _addSnapshotColumns('sales_invoice_items', [
          salesInvoiceItems.taxTreatment,
          salesInvoiceItems.taxCategoryId,
          salesInvoiceItems.taxSnapshotJson,
          salesInvoiceItems.classificationSystem,
          salesInvoiceItems.classificationCode,
          salesInvoiceItems.classificationDescription,
        ], migrator);
        await _addSnapshotColumns('purchase_invoice_items', [
          purchaseInvoiceItems.taxTreatment,
          purchaseInvoiceItems.taxCategoryId,
          purchaseInvoiceItems.taxSnapshotJson,
          purchaseInvoiceItems.classificationSystem,
          purchaseInvoiceItems.classificationCode,
          purchaseInvoiceItems.classificationDescription,
        ], migrator);
        for (final statement in kSchemaExtraStatementsV11) {
          await customStatement(statement);
        }
      }
      if (from < 12) {
        await migrator.createTable(auditEvents);
        await migrator.createTable(auditOutbox);
        for (final statement in kSchemaExtraStatementsV12) {
          await customStatement(statement);
        }
      }
      if (from < 13) {
        await migrator.createTable(auditExportHistory);
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

  /// Adds each of [columns] to [table] unless it already exists (a
  /// simulated older file may have them), so the upgrade is re-runnable.
  Future<void> _addSnapshotColumns(
    String table,
    List<GeneratedColumn> columns,
    Migrator migrator,
  ) async {
    final tableInfo = allTables.firstWhere((t) => t.actualTableName == table);
    for (final column in columns) {
      if (!await _hasColumn(table, column.name)) {
        await migrator.addColumn(tableInfo, column);
      }
    }
  }

  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info($table)').get();
    return rows.any((row) => row.read<String>('name') == column);
  }

  /// 9 -> 10: turns every existing `tax_rates` row into a tax category with
  /// one single-component rule, so products keep exactly the tax they had.
  ///
  /// Everything lands in a "Migrated tax rates" regime and default profile;
  /// the rules have no jurisdiction (they apply everywhere), no dates limit
  /// (effective from 1970) and are not recoverable. Fixed ids and
  /// `INSERT OR IGNORE` make it safe to run twice. Existing invoices are not
  /// touched: their items already hold their own tax figures.
  Future<void> _carryOverLegacyTaxRates() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rates = await customSelect(
      'SELECT id, name, rate_bp, is_exempt, archived_at FROM tax_rates',
    ).get();
    if (rates.isEmpty) {
      return;
    }
    await customStatement(
      'INSERT OR IGNORE INTO tax_regimes (id, name, country_code, '
      'description, currency_code, is_active, created_at, updated_at) '
      "VALUES ('tr-migrated', 'Migrated tax rates', 'XX', "
      "'Rates carried over from earlier versions. They apply in every "
      "location.', COALESCE((SELECT value FROM app_settings "
      "WHERE key = 'currency_code'), 'INR'), 1, ?, ?)",
      [now, now],
    );
    await customStatement(
      'INSERT OR IGNORE INTO tax_profiles (id, name, regime_id, description, '
      'is_default, default_tax_category_id, is_active, created_at, '
      "updated_at) VALUES ('tp-migrated', 'Migrated tax rates', "
      "'tr-migrated', 'Created from the tax rates you had before.', "
      '1, NULL, 1, ?, ?)',
      [now, now],
    );
    for (final rate in rates) {
      final id = rate.read<String>('id');
      final exempt = rate.read<int>('is_exempt') == 1;
      final active = rate.readNullable<int>('archived_at') == null ? 1 : 0;
      await customStatement(
        'INSERT OR IGNORE INTO tax_categories (id, name, code, description, '
        'default_tax_treatment, is_active, created_at, updated_at) '
        'VALUES (?, ?, ?, NULL, ?, ?, ?, ?)',
        [
          'tc-$id',
          rate.read<String>('name'),
          'MIG-$id',
          exempt ? 'exempt' : 'standard_rated',
          active,
          now,
          now,
        ],
      );
      if (!exempt) {
        await customStatement(
          'INSERT OR IGNORE INTO tax_rules (id, tax_profile_id, '
          'tax_category_id, jurisdiction_id, transaction_type, '
          'customer_tax_status, supply_type, supply_relation, '
          'calculation_method, is_stackable, effective_from, '
          'effective_until, priority, is_active, created_at, updated_at) '
          "VALUES (?, 'tp-migrated', ?, NULL, NULL, NULL, NULL, 'any', "
          "'percentage', 0, 0, NULL, 0, ?, ?, ?)",
          ['trl-$id', 'tc-$id', active, now, now],
        );
        await customStatement(
          'INSERT OR IGNORE INTO tax_components (id, tax_rule_id, name, '
          'component_type, rate_basis_points, fixed_amount_minor, '
          'calculation_order, is_compound, is_recoverable, is_active, '
          "created_at, updated_at) VALUES (?, ?, ?, 'custom', ?, NULL, 1, "
          '0, 0, 1, ?, ?)',
          [
            'tcmp-$id',
            'trl-$id',
            rate.read<String>('name'),
            rate.read<int>('rate_bp'),
            now,
            now,
          ],
        );
      }
    }
    await customStatement(
      "UPDATE products SET tax_category_id = 'tc-' || tax_rate_id "
      'WHERE tax_rate_id IS NOT NULL AND tax_category_id IS NULL',
    );
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
