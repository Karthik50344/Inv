import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/returns/data/repositories/drift_return_repository.dart';
import 'package:inventrix/features/returns/domain/entities/return_document.dart';
import 'package:inventrix/features/returns/domain/entities/return_filter.dart';
import 'package:inventrix/features/returns/domain/entities/return_line.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../core/database/database_test_helpers.dart';
import 'data_test_support.dart';

/// Round-trip tests of the Drift return repository on a real in-memory
/// database. (Written without a Flutter SDK: not yet executed.)
void main() {
  late DataHarness h;
  late DriftReturnRepository repo;

  Money inr(int minor) =>
      Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

  ReturnDocument doc({
    String id = 'r1',
    String number = 'SRN-000001',
    String key = 'k1',
    int qty = 1000,
    int net = 1000,
    int tax = 180,
    int refund = 0,
    bool restocked = true,
  }) => ReturnDocument(
    id: id,
    kind: InvoiceKind.sales,
    number: number,
    invoiceId: 'i1',
    invoiceNumber: 'INV-000001',
    partyId: 's1',
    partyName: 'Customer',
    returnDate: DateTime.utc(2026, 1, 10),
    reason: 'Faulty',
    idempotencyKey: key,
    createdAt: DateTime.utc(2026, 1, 10, 9),
    refund: refund == 0
        ? null
        : ReturnRefund(
            amount: inr(refund),
            methodId: 'pm-cash',
            methodName: 'Cash',
            reference: 'ref',
          ),
    lines: [
      ReturnLine(
        id: 'line-$id',
        lineNo: 1,
        invoiceLineId: 'l1',
        productId: 'p1',
        productName: 'Product',
        sku: 'SKU',
        unitSymbol: 'pcs',
        unitDecimalPlaces: 0,
        quantity: Quantity.fromMilli(qty),
        net: inr(net),
        tax: inr(tax),
        restocked: restocked,
        stockCost: restocked ? inr(400) : inr(0),
        note: 'box open',
      ),
    ],
  );

  setUp(() async {
    h = DataHarness();
    await h.db.initialize();
    await insertUnit(h.db, 'u1');
    await insertProduct(h.db, 'p1');
    await insertCustomer(h.db, 's1');
    await insertSalesInvoice(
      h.db,
      'i1',
      status: 'posted',
      number: 'INV-000001',
      postedAt: 5,
    );
    await insertSalesItem(h.db, 'l1', quantityMilli: 3000);
    repo = DriftReturnRepository(h.db);
  });

  tearDown(() async => h.close());

  test('insert then getById round-trips every field', () async {
    final d = doc(refund: 500);
    expect((await repo.insert(d)).isSuccess, isTrue);
    final loaded = (await repo.getById(InvoiceKind.sales, 'r1')).valueOrNull!;
    expect(loaded, d);
    expect(loaded.total, inr(1180));
    expect(loaded.credit, inr(680));
  });

  test('unknown id is NotFound', () async {
    final r = await repo.getById(InvoiceKind.sales, 'nope');
    expect(r.failureOrNull, isA<NotFoundFailure>());
  });

  test('idempotency lookup and forInvoice', () async {
    await repo.insert(doc());
    await repo.insert(
      doc(
        id: 'r2',
        number: 'SRN-000002',
        key: 'k2',
        qty: 500,
        net: 300,
        tax: 54,
      ),
    );
    expect(
      (await repo.findByIdempotencyKey(
        InvoiceKind.sales,
        'k2',
      )).valueOrNull!.id,
      'r2',
    );
    expect(
      (await repo.findByIdempotencyKey(InvoiceKind.sales, 'zz')).valueOrNull,
      isNull,
    );
    final all = (await repo.forInvoice(InvoiceKind.sales, 'i1')).valueOrNull!;
    expect(all.map((d) => d.id), ['r1', 'r2']);
  });

  test('database refuses to return more than was invoiced', () async {
    await repo.insert(doc(qty: 2500, net: 800, tax: 100));
    final r = await repo.insert(
      doc(
        id: 'r2',
        number: 'SRN-000002',
        key: 'k2',
        qty: 1000,
        net: 100,
        tax: 10,
      ),
    );
    expect(r.isFailure, isTrue);
  });

  test('totals, party totals and guard', () async {
    expect(
      (await repo.hasReturns(InvoiceKind.sales, 'i1')).valueOrNull,
      isFalse,
    );
    await repo.insert(doc(refund: 500));
    await repo.insert(
      doc(
        id: 'r2',
        number: 'SRN-000002',
        key: 'k2',
        qty: 500,
        net: 300,
        tax: 54,
      ),
    );
    final totals = (await repo.totalsFor(InvoiceKind.sales, [
      'i1',
      'other',
    ])).valueOrNull!;
    expect(totals['i1']!.returnedMinor, 1180 + 354);
    expect(totals['i1']!.refundedMinor, 500);
    expect(totals['i1']!.count, 2);
    expect(totals.containsKey('other'), isFalse);
    final party = (await repo.partyTotals(
      InvoiceKind.sales,
      's1',
      currencyCode: 'INR',
      decimalPlaces: 2,
    )).valueOrNull!;
    expect(party.returnedMinor, 1534);
    expect(party.refundedMinor, 500);
    final other = (await repo.partyTotals(
      InvoiceKind.sales,
      's1',
      currencyCode: 'USD',
      decimalPlaces: 2,
    )).valueOrNull!;
    expect(other.returnedMinor, 0);
    expect(
      (await repo.hasReturns(InvoiceKind.sales, 'i1')).valueOrNull,
      isTrue,
    );
  });

  test('search filters by kind, invoice and text, newest first', () async {
    await repo.insert(doc());
    await repo.insert(
      doc(
        id: 'r2',
        number: 'SRN-000002',
        key: 'k2',
        qty: 500,
        net: 300,
        tax: 54,
      ),
    );
    final both = (await repo.search(const ReturnFilter())).valueOrNull!;
    expect(both.map((s) => s.number), ['SRN-000002', 'SRN-000001']);
    expect(
      (await repo.search(const ReturnFilter(kind: InvoiceKind.purchase)))
          .valueOrNull,
      isEmpty,
    );
    expect(
      (await repo.search(const ReturnFilter(query: 'srn-000001')))
          .valueOrNull!
          .single
          .lineCount,
      1,
    );
    expect(
      (await repo.search(const ReturnFilter(query: '100%'))).valueOrNull,
      isEmpty,
    );
  });
}
