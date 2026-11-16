import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';

import 'database_test_helpers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
  });

  tearDown(() async => db.close());

  group('initialization', () {
    test('uses schema version 9', () {
      expect(db.schemaVersion, 9);
      expect(AppDatabase.currentSchemaVersion, 9);
    });

    test('enables foreign key enforcement', () async {
      expect(await db.isForeignKeyEnforcementEnabled(), isTrue);
    });

    test('creates every table', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();
      expect(
        names,
        containsAll(<String>[
          'business_profiles',
          'app_settings',
          'categories',
          'units',
          'tax_rates',
          'products',
          'inventory_balances',
          'stock_movements',
          'customers',
          'suppliers',
          'audit_logs',
          'document_sequences',
          'purchase_invoices',
          'purchase_invoice_items',
          'sales_returns',
          'sales_return_items',
          'purchase_returns',
          'purchase_return_items',
        ]),
      );
    });

    test('passes SQLite integrity check', () async {
      expect(await db.integrityCheck(), ['ok']);
    });

    test('seeds default settings', () async {
      final rows = await db
          .customSelect(
            "SELECT value FROM app_settings WHERE key = 'currency_code'",
          )
          .get();
      expect(rows.single.read<String>('value'), 'INR');
      final decimals = await db
          .customSelect(
            'SELECT value FROM app_settings '
            "WHERE key = 'currency_decimal_places'",
          )
          .getSingle();
      expect(decimals.read<String>('value'), '2');
    });
  });

  group('constraints', () {
    test(
      'rejects a product referencing a missing unit (foreign key)',
      () async {
        final failure = await failureOf(
          () => insertProduct(db, 'p1', unitId: 'missing'),
        );
        expect(failure, isA<ValidationFailure>());
      },
    );

    test('rejects duplicate SKUs', () async {
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1', sku: 'A');
      final failure = await failureOf(() => insertProduct(db, 'p2', sku: 'A'));
      expect(failure, isA<DuplicateEntryFailure>());
    });

    test('barcode is optional but unique when present', () async {
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1', sku: 'A');
      await insertProduct(db, 'p2', sku: 'B');
      await insertProduct(db, 'p3', sku: 'C', barcode: '123');
      final failure = await failureOf(
        () => insertProduct(db, 'p4', sku: 'D', barcode: '123'),
      );
      expect(failure, isA<DuplicateEntryFailure>());
    });

    test('category names are unique among active categories only', () async {
      await insertCategory(db, 'c1', name: 'Tools');
      final duplicate = await failureOf(
        () => insertCategory(db, 'c2', name: 'tools'),
      );
      expect(duplicate, isA<DuplicateEntryFailure>());
      await insertCategory(db, 'c3', name: 'Old', archivedAt: 5);
      await insertCategory(db, 'c4', name: 'Old', archivedAt: 6);
      await insertCategory(db, 'c5', name: 'Old');
    });

    test('unit decimal places must be between 0 and 3', () async {
      final failure = await failureOf(
        () => insertUnit(db, 'u1', decimalPlaces: 4),
      );
      expect(failure, isA<ValidationFailure>());
    });

    test('a referenced category cannot be deleted', () async {
      await insertUnit(db, 'u1');
      await insertCategory(db, 'c1');
      await insertProduct(db, 'p1', categoryId: 'c1');
      final failure = await failureOf(
        () => db.customStatement("DELETE FROM categories WHERE id = 'c1'"),
      );
      expect(failure, isA<ValidationFailure>());
    });

    test('inventory balance cannot be negative', () async {
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1');
      final failure = await failureOf(
        () => db.customStatement(
          "INSERT INTO inventory_balances VALUES ('p1', -1, 0, 1)",
        ),
      );
      expect(failure, isA<ValidationFailure>());
    });

    test('zero stock must have zero value', () async {
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1');
      final failure = await failureOf(
        () => db.customStatement(
          "INSERT INTO inventory_balances VALUES ('p1', 0, 100, 1)",
        ),
      );
      expect(failure, isA<ValidationFailure>());
      await db.customStatement(
        "INSERT INTO inventory_balances VALUES ('p1', 2000, 100, 1)",
      );
    });
  });

  group('stock ledger', () {
    setUp(() async {
      await insertUnit(db, 'u1');
      await insertProduct(db, 'p1');
    });

    test('accepts valid movements', () async {
      await insertMovement(db, 'm1');
      await insertMovement(
        db,
        'm2',
        type: 'sale',
        deltaMilli: -500,
        totalCostMinor: -250,
      );
      final count = await db
          .customSelect('SELECT COUNT(*) AS c FROM stock_movements')
          .getSingle();
      expect(count.read<int>('c'), 2);
    });

    test('rejects movements whose sign contradicts their type', () async {
      final failure = await failureOf(
        () => insertMovement(db, 'm1', type: 'sale', totalCostMinor: -1),
      );
      expect(failure, isA<ValidationFailure>());
    });

    test('rejects zero quantity movements', () async {
      final failure = await failureOf(
        () => insertMovement(db, 'm1', deltaMilli: 0, totalCostMinor: 0),
      );
      expect(failure, isA<ValidationFailure>());
    });

    test('requires a reason for adjustments', () async {
      final failure = await failureOf(
        () => insertMovement(db, 'm1', type: 'adjustmentIn'),
      );
      expect(failure, isA<ValidationFailure>());
      await insertMovement(
        db,
        'm2',
        type: 'adjustmentIn',
        reason: 'Found during count',
      );
    });

    test('prevents the same source line posting the same type twice', () async {
      await insertMovement(
        db,
        'm1',
        sourceType: 'purchaseInvoice',
        sourceId: 'inv1',
        sourceLineId: 'line1',
      );
      final failure = await failureOf(
        () => insertMovement(
          db,
          'm2',
          sourceType: 'purchaseInvoice',
          sourceId: 'inv1',
          sourceLineId: 'line1',
        ),
      );
      expect(failure, isA<DuplicateEntryFailure>());
    });

    test('is append-only: updates and deletes are rejected', () async {
      await insertMovement(db, 'm1');
      final update = await failureOf(
        () => db.customStatement(
          "UPDATE stock_movements SET reason = 'x' WHERE id = 'm1'",
        ),
      );
      final delete = await failureOf(
        () => db.customStatement("DELETE FROM stock_movements WHERE id = 'm1'"),
      );
      expect(update, isA<DatabaseFailure>());
      expect(delete, isA<DatabaseFailure>());
    });
  });
}
