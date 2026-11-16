import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';

import 'database_test_helpers.dart';

/// Constraint and trigger tests for the payment tables against the real
/// schema. (Written without a Flutter SDK: not yet executed.)
void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    await insertCustomer(db, 'c1');
    await insertSupplier(db, 's1');
    await insertSalesInvoice(
      db,
      'i1',
      status: 'posted',
      number: 'INV-000001',
      postedAt: 5,
      totalMinor: 10000,
      netMinor: 10000,
      taxMinor: 0,
    );
    await insertPurchaseInvoice(
      db,
      'b1',
      status: 'posted',
      number: 'PUR-000001',
      postedAt: 5,
      totalMinor: 5000,
      netMinor: 5000,
      taxMinor: 0,
    );
  });

  tearDown(() async => db.close());

  Future<void> pay(
    String id, {
    String kind = 'payment',
    String partyType = 'customer',
    String? customerId = 'c1',
    String? supplierId,
    int amount = 10000,
    String? refundOf,
    String? key,
    String? number,
  }) => db.customStatement(
    'INSERT INTO payments (id, number, kind, party_type, customer_id, '
    'supplier_id, party_name, method_id, method_name, payment_date, '
    'amount_minor, currency_code, decimal_places, refund_of_payment_id, '
    "idempotency_key, created_at) VALUES (?, ?, ?, ?, ?, ?, 'Party', "
    "'pm-cash', 'Cash', 1, ?, 'INR', 2, ?, ?, 1)",
    [
      id,
      number ?? 'N-$id',
      kind,
      partyType,
      customerId,
      supplierId,
      amount,
      refundOf,
      key ?? 'key-$id',
    ],
  );

  Future<void> alloc(
    String id,
    String paymentId,
    int amount, {
    String? sales = 'i1',
    String? purchase,
  }) => db.customStatement(
    'INSERT INTO payment_allocations (id, payment_id, sales_invoice_id, '
    "purchase_invoice_id, invoice_number, amount_minor, created_at) "
    "VALUES (?, ?, ?, ?, 'N', ?, 1)",
    [id, paymentId, sales, purchase, amount],
  );

  test('fresh databases seed the starter payment methods', () async {
    final rows = await db
        .customSelect('SELECT name FROM payment_methods ORDER BY name')
        .get();
    expect(rows.map((r) => r.read<String>('name')).toList(), [
      'Bank transfer',
      'Card',
      'Cash',
      'Other',
    ]);
  });

  group('payment header', () {
    test('needs a positive amount', () async {
      expect(
        await failureOf(() => pay('p1', amount: 0)),
        isA<ValidationFailure>(),
      );
    });

    test('a customer payment names exactly a customer', () async {
      expect(
        await failureOf(() => pay('p1', customerId: null)),
        isA<ValidationFailure>(),
      );
      expect(
        await failureOf(() => pay('p1', supplierId: 's1')),
        isA<ValidationFailure>(),
      );
      await pay(
        'p2',
        partyType: 'supplier',
        customerId: null,
        supplierId: 's1',
      );
    });

    test('only refunds reference a payment, and they must', () async {
      await pay('p1');
      expect(
        await failureOf(() => pay('p2', refundOf: 'p1')),
        isA<ValidationFailure>(),
      );
      expect(
        await failureOf(() => pay('r1', kind: 'refund')),
        isA<ValidationFailure>(),
      );
      await pay('r2', kind: 'refund', refundOf: 'p1', amount: 100);
    });

    test('numbers and idempotency keys are unique', () async {
      await pay('p1', number: 'PAY-000001', key: 'k1');
      expect(
        await failureOf(() => pay('p2', number: 'PAY-000001', key: 'k2')),
        isA<DuplicateEntryFailure>(),
      );
      expect(
        await failureOf(() => pay('p3', number: 'PAY-000003', key: 'k1')),
        isA<DuplicateEntryFailure>(),
      );
    });

    test('unknown parties are rejected by the foreign key', () async {
      expect(
        await failureOf(() => pay('p1', customerId: 'nobody')),
        isA<ValidationFailure>(),
      );
    });
  });

  group('append-only rows', () {
    test('payments cannot be changed or deleted', () async {
      await pay('p1');
      expect(
        await failureOf(
          () => db.customStatement(
            'UPDATE payments SET amount_minor = 1 WHERE id = ?',
            ['p1'],
          ),
        ),
        isA<DatabaseFailure>(),
      );
      expect(
        await failureOf(
          () => db.customStatement('DELETE FROM payments WHERE id = ?', ['p1']),
        ),
        isA<DatabaseFailure>(),
      );
    });

    test('allocations and reversals cannot be changed or deleted', () async {
      await pay('p1');
      await alloc('a1', 'p1', 1000);
      await db.customStatement(
        "INSERT INTO payment_reversals VALUES ('v1', 'p1', 'x', 2)",
      );
      for (final sql in [
        'UPDATE payment_allocations SET amount_minor = 5',
        'DELETE FROM payment_allocations',
        'UPDATE payment_reversals SET reason = \'y\'',
        'DELETE FROM payment_reversals',
      ]) {
        expect(
          await failureOf(() => db.customStatement(sql)),
          isA<DatabaseFailure>(),
          reason: sql,
        );
      }
    });

    test('a payment can be reversed only once', () async {
      await pay('p1');
      await db.customStatement(
        "INSERT INTO payment_reversals VALUES ('v1', 'p1', 'x', 2)",
      );
      expect(
        await failureOf(
          () => db.customStatement(
            "INSERT INTO payment_reversals VALUES ('v2', 'p1', 'x', 3)",
          ),
        ),
        isA<DuplicateEntryFailure>(),
      );
    });
  });

  group('allocations', () {
    test('reference exactly one invoice', () async {
      await pay('p1');
      expect(
        await failureOf(() => alloc('a1', 'p1', 100, sales: null)),
        isA<Failure>(),
      );
      expect(
        await failureOf(() => alloc('a2', 'p1', 100, purchase: 'b1')),
        isA<Failure>(),
      );
    });

    test('payments are positive and refunds negative', () async {
      await pay('p1');
      await alloc('a1', 'p1', 5000);
      expect(
        await failureOf(() => alloc('a2', 'p1', -1)),
        isA<DatabaseFailure>(),
      );
      await pay('r1', kind: 'refund', refundOf: 'p1', amount: 100);
      expect(
        await failureOf(() => alloc('a3', 'r1', 100)),
        isA<DatabaseFailure>(),
      );
      await alloc('a4', 'r1', -100);
    });

    test('never exceed the invoice total', () async {
      await pay('p1');
      await alloc('a1', 'p1', 6000);
      expect(
        await failureOf(() => alloc('a2', 'p1', 4001)),
        isA<DatabaseFailure>(),
      );
      await alloc('a3', 'p1', 4000);
      expect(
        await failureOf(() => alloc('a4', 'p1', 1)),
        isA<DatabaseFailure>(),
      );
    });

    test('cannot drive an invoice below zero through refunds', () async {
      await pay('p1');
      await alloc('a1', 'p1', 1000);
      await pay('r1', kind: 'refund', refundOf: 'p1', amount: 1001);
      expect(
        await failureOf(() => alloc('a2', 'r1', -1001)),
        isA<DatabaseFailure>(),
      );
    });

    test('reversed payments free up the invoice again', () async {
      await pay('p1');
      await alloc('a1', 'p1', 10000);
      await db.customStatement(
        "INSERT INTO payment_reversals VALUES ('v1', 'p1', 'x', 2)",
      );
      await pay('p2');
      await alloc('a2', 'p2', 10000);
    });

    test('purchase invoices are limited the same way', () async {
      await pay(
        'p1',
        partyType: 'supplier',
        customerId: null,
        supplierId: 's1',
      );
      await alloc('a1', 'p1', 5000, sales: null, purchase: 'b1');
      expect(
        await failureOf(
          () => alloc('a2', 'p1', 1, sales: null, purchase: 'b1'),
        ),
        isA<DatabaseFailure>(),
      );
    });
  });

  test('foreign keys stop deleting a paid invoice or a method', () async {
    await pay('p1');
    final rows = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM payments WHERE id = ?',
          variables: [Variable.withString('p1')],
        )
        .getSingle();
    expect(rows.read<int>('c'), 1);
    expect(
      await failureOf(
        () => db.customStatement(
          "DELETE FROM payment_methods WHERE id = 'pm-cash'",
        ),
      ),
      isA<ValidationFailure>(),
    );
  });
}
