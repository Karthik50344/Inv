import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';

import 'database_test_helpers.dart';

/// Constraint and trigger tests for the sale tables, against the real
/// schema.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    await insertUnit(db, 'u1');
    await insertProduct(db, 'p1');
    await insertCustomer(db, 's1');
  });

  tearDown(() async => db.close());

  Future<String> statusOf(String id) async {
    final row = await db
        .customSelect(
          'SELECT status FROM sales_invoices WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return row.read<String>('status');
  }

  Future<void> post(String id, {String number = 'INV-000001'}) =>
      db.customStatement(
        "UPDATE sales_invoices SET status = 'posted', number = ?, "
        'posted_at = 5 WHERE id = ?',
        [number, id],
      );

  group('invoice header constraints', () {
    test('accepts a draft without a number', () async {
      await insertSalesInvoice(db, 'i1');
      expect(await statusOf('i1'), 'draft');
    });

    test('rejects an unknown status', () async {
      expect(
        await failureOf(() => insertSalesInvoice(db, 'i1', status: 'bogus')),
        isA<ValidationFailure>(),
      );
    });

    test('a number exists exactly for posted or voided documents', () async {
      expect(
        await failureOf(
          () => insertSalesInvoice(db, 'i1', number: 'INV-000009'),
        ),
        isA<ValidationFailure>(),
      );
      expect(
        await failureOf(
          () => insertSalesInvoice(db, 'i2', status: 'posted', postedAt: 1),
        ),
        isA<ValidationFailure>(),
      );
    });

    test('numbers are unique', () async {
      await insertSalesInvoice(
        db,
        'i1',
        status: 'posted',
        number: 'INV-000001',
        postedAt: 1,
      );
      expect(
        await failureOf(
          () => insertSalesInvoice(
            db,
            'i2',
            status: 'posted',
            number: 'INV-000001',
            postedAt: 1,
          ),
        ),
        isA<DuplicateEntryFailure>(),
      );
    });

    test('total must equal net plus tax', () async {
      expect(
        await failureOf(() => insertSalesInvoice(db, 'i1', totalMinor: 999)),
        isA<ValidationFailure>(),
      );
    });

    test('a sale may have no customer (walk-in)', () async {
      await insertSalesInvoice(db, 'w1', customerId: null);
      final row = await db
          .customSelect(
            'SELECT customer_id FROM sales_invoices WHERE id = ?',
            variables: [Variable.withString('w1')],
          )
          .getSingle();
      expect(row.read<String?>('customer_id'), isNull);
    });

    test('the customer must exist', () async {
      expect(
        await failureOf(
          () => insertSalesInvoice(db, 'i1', customerId: 'nope'),
        ),
        isA<ValidationFailure>(),
      );
    });

    test('a customer with invoices cannot be deleted', () async {
      await insertSalesInvoice(db, 'i1');
      expect(
        await failureOf(
          () => db.customStatement("DELETE FROM customers WHERE id = 's1'"),
        ),
        isA<ValidationFailure>(),
      );
    });
  });

  group('line constraints', () {
    setUp(() => insertSalesInvoice(db, 'i1'));

    test('accepts a line on a draft', () async {
      await insertSalesItem(db, 'l1');
      final row = await db
          .customSelect('SELECT COUNT(*) AS c FROM sales_invoice_items')
          .getSingle();
      expect(row.read<int>('c'), 1);
    });

    test('quantity must be positive', () async {
      expect(
        await failureOf(() => insertSalesItem(db, 'l1', quantityMilli: 0)),
        isA<ValidationFailure>(),
      );
    });

    test('line numbers are unique per invoice', () async {
      await insertSalesItem(db, 'l1');
      expect(
        await failureOf(() => insertSalesItem(db, 'l2')),
        isA<DuplicateEntryFailure>(),
      );
    });

    test('a saled product cannot be deleted', () async {
      await insertSalesItem(db, 'l1');
      expect(
        await failureOf(
          () => db.customStatement("DELETE FROM products WHERE id = 'p1'"),
        ),
        isA<ValidationFailure>(),
      );
    });
  });

  group('immutability of posted documents', () {
    setUp(() async {
      await insertSalesInvoice(db, 'i1');
      await insertSalesItem(db, 'l1');
      await post('i1');
    });

    test('lines cannot be inserted, changed or deleted', () async {
      expect(
        await failureOf(() => insertSalesItem(db, 'l2', lineNo: 2)),
        isA<DatabaseFailure>(),
      );
      expect(
        await failureOf(
          () => db.customStatement(
            'UPDATE sales_invoice_items SET unit_price_minor = 1',
          ),
        ),
        isA<DatabaseFailure>(),
      );
      expect(
        await failureOf(
          () => db.customStatement('DELETE FROM sales_invoice_items'),
        ),
        isA<DatabaseFailure>(),
      );
    });

    test('financial columns cannot change', () async {
      expect(
        await failureOf(
          () => db.customStatement(
            'UPDATE sales_invoices SET total_minor = 1, net_total_minor = 1, tax_total_minor = 0',
          ),
        ),
        isA<DatabaseFailure>(),
      );
      expect(
        await failureOf(
          () => db.customStatement(
            "UPDATE sales_invoices SET customer_name = 'X'",
          ),
        ),
        isA<DatabaseFailure>(),
      );
      expect(
        await failureOf(
          () => db.customStatement(
            "UPDATE sales_invoices SET status = 'draft'",
          ),
        ),
        isA<DatabaseFailure>(),
      );
      expect(await statusOf('i1'), 'posted');
    });

    test('invoices cannot be deleted', () async {
      expect(
        await failureOf(
          () => db.customStatement('DELETE FROM sales_invoices'),
        ),
        isA<DatabaseFailure>(),
      );
    });

    test('a posted invoice can be voided, and then nothing changes', () async {
      await db.customStatement(
        "UPDATE sales_invoices SET status = 'voided', voided_at = 9, "
        "void_reason = 'mistake', updated_at = 9 WHERE id = 'i1'",
      );
      expect(await statusOf('i1'), 'voided');
      expect(
        await failureOf(
          () => db.customStatement("UPDATE sales_invoices SET notes = 'late'"),
        ),
        isA<DatabaseFailure>(),
      );
    });

    test('voiding needs a reason and a time', () async {
      expect(
        await failureOf(
          () => db.customStatement(
            "UPDATE sales_invoices SET status = 'voided'",
          ),
        ),
        isA<ValidationFailure>(),
      );
    });
  });

  group('drafts', () {
    test('lines of a draft can be replaced', () async {
      await insertSalesInvoice(db, 'i1');
      await insertSalesItem(db, 'l1');
      await db.customStatement('DELETE FROM sales_invoice_items');
      await insertSalesItem(db, 'l2');
    });

    test('a cancelled invoice is frozen', () async {
      await insertSalesInvoice(db, 'i1');
      await db.customStatement(
        "UPDATE sales_invoices SET status = 'cancelled'",
      );
      expect(
        await failureOf(
          () => db.customStatement(
            "UPDATE sales_invoices SET status = 'draft'",
          ),
        ),
        isA<DatabaseFailure>(),
      );
    });
  });
}
