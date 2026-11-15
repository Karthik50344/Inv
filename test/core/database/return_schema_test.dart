import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';

import 'database_test_helpers.dart';

/// Constraint and trigger tests for the return tables, against the real
/// schema. (Written without a Flutter SDK: not yet executed; the SQL itself
/// was run against SQLite.)
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    await insertUnit(db, 'u1');
    await insertProduct(db, 'p1');
    await insertCustomer(db, 's1');
    await insertSalesInvoice(
      db,
      'i1',
      status: 'posted',
      number: 'INV-000001',
      postedAt: 5,
    );
    await insertSalesItem(db, 'l1', quantityMilli: 3000);
    await insertSalesInvoice(db, 'i2');
  });

  tearDown(() async => db.close());

  Future<void> header(
    String id, {
    String invoiceId = 'i1',
    String number = 'SRN-000001',
    String key = 'k1',
    int total = 1180,
    int net = 1000,
    int tax = 180,
    int refund = 0,
    String? method,
  }) => db.customStatement(
    'INSERT INTO sales_returns (id, number, invoice_id, invoice_number, '
    'customer_id, customer_name, return_date, reason, currency_code, '
    'decimal_places, net_total_minor, tax_total_minor, total_minor, '
    'refund_amount_minor, refund_method_id, refund_method_name, '
    'idempotency_key, created_at) VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?, 2, ?, ?, '
    '?, ?, ?, ?, ?, 1)',
    [
      id,
      number,
      invoiceId,
      'INV-000001',
      's1',
      'Customer',
      'Faulty',
      'INR',
      net,
      tax,
      total,
      refund,
      method,
      method == null ? null : 'Cash',
      key,
    ],
  );

  Future<void> item(
    String id, {
    String returnId = 'r1',
    int lineNo = 1,
    String invoiceItemId = 'l1',
    int qty = 1000,
    int net = 1000,
    int tax = 180,
    int restocked = 1,
    int cost = 400,
  }) => db.customStatement(
    'INSERT INTO sales_return_items (id, return_id, line_no, '
    'invoice_item_id, product_id, product_name, sku, unit_symbol, '
    'unit_decimal_places, quantity_milli, net_minor, tax_minor, total_minor, '
    'restocked, stock_cost_minor) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, '
    '?, ?, ?)',
    [
      id,
      returnId,
      lineNo,
      invoiceItemId,
      'p1',
      'Product',
      'SKU',
      'pcs',
      qty,
      net,
      tax,
      net + tax,
      restocked,
      cost,
    ],
  );

  group('return header constraints', () {
    test('accepts a return of a posted invoice', () async {
      await header('r1');
      await item('a');
    });

    test('rejects a return of a draft invoice', () async {
      expect(
        await failureOf(() => header('r1', invoiceId: 'i2')),
        isA<Failure>(),
      );
    });

    test('total must be net plus tax', () async {
      expect(
        await failureOf(() => header('r1', total: 999)),
        isA<ValidationFailure>(),
      );
    });

    test('refund cannot exceed the total and needs a method', () async {
      expect(
        await failureOf(() => header('r1', refund: 2000, method: 'pm-cash')),
        isA<ValidationFailure>(),
      );
      expect(
        await failureOf(() => header('r1', refund: 100)),
        isA<ValidationFailure>(),
      );
      await header('r1', refund: 100, method: 'pm-cash');
    });

    test('number and idempotency key are unique', () async {
      await header('r1');
      expect(
        await failureOf(() => header('r2', key: 'k2')),
        isA<DuplicateEntryFailure>(),
      );
      expect(
        await failureOf(() => header('r2', number: 'SRN-000002')),
        isA<DuplicateEntryFailure>(),
      );
    });
  });

  group('return lines', () {
    setUp(() async {
      await header('r1');
    });

    test('quantities over the invoiced line are rejected', () async {
      await item('a', qty: 2000, net: 600, tax: 100);
      await header('r2', number: 'SRN-000002', key: 'k2');
      expect(
        await failureOf(
          () => item('b', returnId: 'r2', qty: 1500, net: 100, tax: 10),
        ),
        isA<Failure>(),
      );
      await item('b', returnId: 'r2', qty: 1000, net: 400, tax: 80);
    });

    test('net and tax cannot exceed the invoiced line either', () async {
      await item('a', qty: 1000, net: 900, tax: 100);
      await header('r2', number: 'SRN-000002', key: 'k2');
      expect(
        await failureOf(
          () => item('b', returnId: 'r2', qty: 1000, net: 200, tax: 10),
        ),
        isA<Failure>(),
      );
    });

    test('a line of another invoice is rejected', () async {
      await insertSalesItem(db, 'l2', invoiceId: 'i2', productId: 'p1');
      expect(
        await failureOf(() => item('a', invoiceItemId: 'l2')),
        isA<Failure>(),
      );
    });

    test('an unrestocked line carries no stock cost', () async {
      expect(
        await failureOf(() => item('a', restocked: 0, cost: 5)),
        isA<ValidationFailure>(),
      );
    });
  });

  group('append-only', () {
    setUp(() async {
      await header('r1');
      await item('a');
    });

    test('returns and lines cannot be edited or deleted', () async {
      for (final sql in [
        "UPDATE sales_returns SET reason = 'x'",
        'DELETE FROM sales_returns',
        'UPDATE sales_return_items SET quantity_milli = 1',
        'DELETE FROM sales_return_items',
      ]) {
        expect(
          await failureOf(() => db.customStatement(sql)),
          isA<DatabaseFailure>(),
          reason: sql,
        );
      }
    });

    test('an invoice with returns cannot be voided', () async {
      expect(
        await failureOf(
          () => db.customStatement(
            "UPDATE sales_invoices SET status = 'voided', voided_at = 9, "
            "void_reason = 'x' WHERE id = 'i1'",
          ),
        ),
        isA<Failure>(),
      );
    });
  });
}
