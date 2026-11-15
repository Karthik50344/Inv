import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';

import 'database_test_helpers.dart';

/// Migration tests for the file-backed database.
///
/// The 1 -> 2 test *simulates* a version 1 file (drops the v2 tables and
/// rewinds `user_version`). Once `drift_dev schema dump` snapshots exist,
/// replace it with `SchemaVerifier` tests (see docs/database/migrations.md).
void main() {
  late Directory tempDir;
  late File file;

  Future<int> count(AppDatabase db, String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('inventrix_db_test_');
    file = File('${tempDir.path}/inventory_management.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('records the current schema version in the file', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    final row = await db.customSelect('PRAGMA user_version').getSingle();
    expect(row.read<int>('user_version'), AppDatabase.currentSchemaVersion);
    await db.close();
  });

  test('reopening keeps data and does not re-seed or recreate', () async {
    var db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    await insertUnit(db, 'u1');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    expect(await count(db, 'units'), 1);
    expect(await count(db, 'app_settings'), 4);
    expect(await db.isForeignKeyEnforcementEnabled(), isTrue);
    expect(await db.integrityCheck(), ['ok']);
    await db.close();
  });

  test(
    'upgrading 1 -> 2 adds party tables and preserves existing data',
    () async {
      var db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      await insertUnit(db, 'u1');
      await insertCategory(db, 'c1', name: 'Tools');
      await insertProduct(db, 'p1', categoryId: 'c1');
      for (final table in [
        'payment_allocations',
        'payment_reversals',
        'payments',
        'payment_methods',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final table in ['attachments', 'expenses', 'expense_categories']) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final table in [
        'purchase_return_items',
        'purchase_returns',
        'sales_return_items',
        'sales_returns',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('DROP TABLE sales_invoice_items');
      await db.customStatement('DROP TABLE sales_invoices');
      await db.customStatement('DROP TABLE purchase_invoice_items');
      await db.customStatement('DROP TABLE purchase_invoices');
      await db.customStatement('DROP TABLE document_sequences');
      await db.customStatement('DROP TABLE customers');
      await db.customStatement('DROP TABLE suppliers');
      await db.customStatement('DROP TABLE audit_logs');
      await db.customStatement('PRAGMA user_version = 1');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      await db.initialize();

      expect(await count(db, 'customers'), 0);
      expect(await count(db, 'suppliers'), 0);
      expect(await count(db, 'units'), 1);
      expect(await count(db, 'categories'), 1);
      expect(await count(db, 'products'), 1);
      final indexes = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final names = indexes.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll(<String>['idx_customers_name', 'idx_suppliers_name']),
      );
      expect(await count(db, 'audit_logs'), 0);
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      expect(
        version.read<int>('user_version'),
        AppDatabase.currentSchemaVersion,
      );
      expect(await db.integrityCheck(), ['ok']);
      await db.close();
    },
  );

  test(
    'upgrading 2 -> 3 adds the append-only audit log and keeps data',
    () async {
      var db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1');
      await insertMovement(db, 'm1');
      for (final table in [
        'payment_allocations',
        'payment_reversals',
        'payments',
        'payment_methods',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final table in ['attachments', 'expenses', 'expense_categories']) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final table in [
        'purchase_return_items',
        'purchase_returns',
        'sales_return_items',
        'sales_returns',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('DROP TABLE sales_invoice_items');
      await db.customStatement('DROP TABLE sales_invoices');
      await db.customStatement('DROP TABLE purchase_invoice_items');
      await db.customStatement('DROP TABLE purchase_invoices');
      await db.customStatement('DROP TABLE document_sequences');
      await db.customStatement('DROP TABLE audit_logs');
      await db.customStatement('PRAGMA user_version = 2');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      expect(await count(db, 'stock_movements'), 1);
      expect(await count(db, 'products'), 1);
      await db.customStatement(
        'INSERT INTO audit_logs (id, entity_type, entity_id, action, summary, '
        "occurred_at) VALUES ('a1', 'stock', 'p1', 'x', 'y', 1)",
      );
      final update = await failureOf(
        () => db.customStatement("UPDATE audit_logs SET summary = 'z'"),
      );
      final delete = await failureOf(
        () => db.customStatement('DELETE FROM audit_logs'),
      );
      expect(update, isA<DatabaseFailure>());
      expect(delete, isA<DatabaseFailure>());
      expect(await db.integrityCheck(), ['ok']);
      await db.close();
    },
  );

  test(
    'upgrading 3 -> 4 adds purchases, keeps data and enforces immutability',
    () async {
      var db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1');
      await insertMovement(db, 'm1');
      for (final table in [
        'payment_allocations',
        'payment_reversals',
        'payments',
        'payment_methods',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final table in ['attachments', 'expenses', 'expense_categories']) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final table in [
        'purchase_return_items',
        'purchase_returns',
        'sales_return_items',
        'sales_returns',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('DROP TABLE sales_invoice_items');
      await db.customStatement('DROP TABLE sales_invoices');
      await db.customStatement('DROP TABLE purchase_invoice_items');
      await db.customStatement('DROP TABLE purchase_invoices');
      await db.customStatement('DROP TABLE document_sequences');
      await db.customStatement('PRAGMA user_version = 3');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      expect(await count(db, 'stock_movements'), 1);
      expect(await count(db, 'products'), 1);
      await insertSupplier(db, 's1');
      await insertPurchaseInvoice(db, 'i1');
      await insertPurchaseItem(db, 'l1');
      await db.customStatement(
        'UPDATE purchase_invoices SET status = \'posted\', number = \'PUR-000001\', '
        'posted_at = 2 WHERE id = \'i1\'',
      );
      final lineEdit = await failureOf(
        () => db.customStatement(
          'UPDATE purchase_invoice_items SET quantity_milli = 5000',
        ),
      );
      expect(lineEdit, isA<DatabaseFailure>());
      final idx = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name IN ('uq_purchase_invoices_number', 'idx_audit_logs_entity')",
          )
          .get();
      expect(idx.length, 2);
      expect(await db.integrityCheck(), ['ok']);
      await db.close();
    },
  );

  test(
    'upgrading 4 -> 5 adds sales, keeps data and enforces immutability',
    () async {
      var db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1');
      await insertMovement(db, 'm1');
      await insertSupplier(db, 's9');
      await insertPurchaseInvoice(db, 'pi1', supplierId: 's9');
      for (final table in [
        'payment_allocations',
        'payment_reversals',
        'payments',
        'payment_methods',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final table in ['attachments', 'expenses', 'expense_categories']) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final table in [
        'purchase_return_items',
        'purchase_returns',
        'sales_return_items',
        'sales_returns',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('DROP TABLE sales_invoice_items');
      await db.customStatement('DROP TABLE sales_invoices');
      await db.customStatement('PRAGMA user_version = 4');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      expect(await count(db, 'stock_movements'), 1);
      expect(await count(db, 'purchase_invoices'), 1);
      await insertCustomer(db, 's1');
      await insertSalesInvoice(db, 'i1');
      await insertSalesInvoice(db, 'walkin', customerId: null);
      await insertSalesItem(db, 'l1');
      await db.customStatement(
        "UPDATE sales_invoices SET status = 'posted', number = 'INV-000001', "
        "posted_at = 2 WHERE id = 'i1'",
      );
      final lineEdit = await failureOf(
        () => db.customStatement(
          'UPDATE sales_invoice_items SET quantity_milli = 5000',
        ),
      );
      expect(lineEdit, isA<DatabaseFailure>());
      final idx = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'uq_sales_invoices_number'",
          )
          .get();
      expect(idx.length, 1);
      expect(await db.integrityCheck(), ['ok']);
      await db.close();
    },
  );

  test(
    'upgrading 5 -> 6 adds payments, keeps data, seeds methods and enforces '
    'append-only rows',
    () async {
      var db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      await insertCustomer(db, 'c1');
      await insertSalesInvoice(
        db,
        'i1',
        status: 'posted',
        number: 'INV-000001',
        postedAt: 2,
        totalMinor: 1000,
        netMinor: 1000,
        taxMinor: 0,
      );
      for (final table in [
        'payment_allocations',
        'payment_reversals',
        'payments',
        'payment_methods',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('PRAGMA user_version = 5');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      expect(await count(db, 'sales_invoices'), 1);
      expect(await count(db, 'payment_methods'), 4);
      await db.customStatement(
        'INSERT INTO payments (id, number, kind, party_type, customer_id, '
        'party_name, method_id, method_name, payment_date, amount_minor, '
        'currency_code, decimal_places, idempotency_key, created_at) VALUES '
        "('p1', 'PAY-000001', 'payment', 'customer', 'c1', 'Acme', 'pm-cash', "
        "'Cash', 1, 500, 'INR', 2, 'k1', 1)",
      );
      final edit = await failureOf(
        () => db.customStatement('UPDATE payments SET amount_minor = 1'),
      );
      expect(edit, isA<DatabaseFailure>());
      expect(await db.integrityCheck(), ['ok']);
      await db.close();
    },
  );

  test(
    'upgrading 6 -> 7 adds the return tables and their guards',
    () async {
      var db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1');
      for (final table in ['attachments', 'expenses', 'expense_categories']) {
        await db.customStatement('DROP TABLE $table');
      }
      for (final table in [
        'purchase_return_items',
        'purchase_returns',
        'sales_return_items',
        'sales_returns',
      ]) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('PRAGMA user_version = 6');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      final tables = (await db
              .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
              .get())
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(
        tables,
        containsAll(<String>[
          'sales_returns',
          'sales_return_items',
          'purchase_returns',
          'purchase_return_items',
        ]),
      );
      final objects = (await db
              .customSelect(
                "SELECT name FROM sqlite_master "
                "WHERE type IN ('index', 'trigger')",
              )
              .get())
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(
        objects,
        containsAll(<String>[
          'uq_sales_returns_number',
          'uq_purchase_returns_idempotency',
          'trg_sales_return_items_not_more_than_sold',
          'trg_purchase_returns_posted_invoice',
          'trg_sales_invoices_void_after_returns',
        ]),
      );
      expect(await count(db, 'products'), 1);
      expect(await db.integrityCheck(), ['ok']);
      await db.close();
    },
  );

  test(
    'upgrading 7 -> 8 adds expenses, attachments and seeded categories',
    () async {
      var db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1');
      for (final table in ['attachments', 'expenses', 'expense_categories']) {
        await db.customStatement('DROP TABLE $table');
      }
      await db.customStatement('PRAGMA user_version = 7');
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      await db.initialize();
      final tables = (await db
              .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
              .get())
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(
        tables,
        containsAll(<String>['expense_categories', 'expenses', 'attachments']),
      );
      final objects = (await db
              .customSelect(
                "SELECT name FROM sqlite_master "
                "WHERE type IN ('index', 'trigger')",
              )
              .get())
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(
        objects,
        containsAll(<String>[
          'uq_expense_categories_name_active',
          'uq_expenses_number',
          'trg_expenses_protect',
          'trg_expenses_no_delete',
          'trg_attachments_delete_draft_only',
        ]),
      );
      expect(await count(db, 'expense_categories'), 8);
      expect(await count(db, 'products'), 1);
      expect(await db.integrityCheck(), ['ok']);
      await db.close();
    },
  );

  test('uses the specified database file name', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    await db.close();
    expect(file.existsSync(), isTrue);
    expect(file.uri.pathSegments.last, 'inventory_management.sqlite');
  });
}
