import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/domain/services/invoice_layout.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import '../../support/sales_fakes.dart';

String money(Money m) => 'INR ${m.toPlainString()}';
String date(DateTime d) => '${d.year}-${d.month}-${d.day}';

void main() {
  shareTests();
  late SalesFixture f;
  setUp(() => f = SalesFixture());

  test('the layout prints exactly the stored invoice', () async {
    f.addTaxRate();
    final p = await f.addTaxedProduct(taxRateId: 'gst18', selling: '100');
    await f.stockUp(p.id, '10');
    final d = await f.draft([
      SalesLineInput(
        productId: p.id,
        quantity: '2',
        discountKind: DiscountKind.percent,
        discountValue: '10',
      ),
    ]);
    final posted = (await f.post(d.id)).valueOrNull!;
    final layout = InvoiceLayout.from(
      posted,
      const BusinessProfile(
        name: 'Test Traders',
        address: '1 Market Road\nChennai',
        phone: '555',
      ),
      money: money,
      date: date,
    );
    expect(layout.title, 'TAX INVOICE');
    expect(layout.businessName, 'Test Traders');
    expect(layout.businessLines, ['1 Market Road', 'Chennai', 'Phone: 555']);
    expect(layout.meta.first.value, 'INV-000001');
    expect(layout.meta.map((m) => m.label), contains('Bill to'));
    expect(
      layout.meta.firstWhere((m) => m.label == 'Bill to').value,
      'Acme Traders',
    );
    expect(layout.rows.single.length, layout.columns.length);
    final row = layout.rows.single;
    expect(row[2], '2 pcs');
    expect(row[3], 'INR 100.00');
    expect(row[4], 'INR 20.00');
    expect(row[5], '18% INR 32.40');
    expect(row[6], 'INR 212.40');
    expect(layout.totals.first, const InvoiceField('Subtotal', 'INR 200.00'));
    expect(layout.totals.map((t) => t.label).toList(), [
      'Subtotal',
      'Discount',
      'Tax',
    ]);
    expect(layout.grandTotal.value, 'INR 212.40');
    expect(layout.fileName, 'INV-000001.pdf');
    expect(layout.statusNote, isNull);
  });

  test('a voided invoice is marked VOID with its reason', () async {
    final p = await f.addProduct(selling: '10');
    await f.stockUp(p.id, '5');
    final d = await f.draft([SalesLineInput(productId: p.id, quantity: '1')]);
    await f.post(d.id);
    final voided = (await f.voidSale(
      d.id,
      reason: 'Wrong customer',
    )).valueOrNull!;
    final layout = InvoiceLayout.from(
      voided,
      BusinessProfile.placeholder,
      money: money,
      date: date,
    );
    expect(layout.statusNote, 'VOID: Wrong customer');
    expect(layout.title, 'TAX INVOICE');
  });

  test('a walk-in invoice says so', () async {
    final p = await f.addProduct(selling: '10');
    await f.stockUp(p.id, '5');
    final d = await f.draft([
      SalesLineInput(productId: p.id, quantity: '1'),
    ], customerId: null);
    final layout = InvoiceLayout.from(
      d,
      BusinessProfile.placeholder,
      money: money,
      date: date,
    );
    expect(layout.title, 'DRAFT INVOICE');
    expect(
      layout.meta.firstWhere((m) => m.label == 'Bill to').value,
      'Walk-in customer',
    );
    expect(layout.fileName, startsWith('draft-'));
  });

  test('fractional tax rates print without trailing zeros', () async {
    f.addTaxRate(id: 'r', name: 'R', bp: 250);
    final p = await f.addTaxedProduct(taxRateId: 'r', selling: '100');
    await f.stockUp(p.id, '5');
    final d = await f.draft([SalesLineInput(productId: p.id, quantity: '1')]);
    final layout = InvoiceLayout.from(
      d,
      BusinessProfile.placeholder,
      money: money,
      date: date,
    );
    expect(layout.rows.single[5], startsWith('2.5% '));
  });
}

void shareTests() {
  group('ShareInvoicePdf', _shareGroup);
}

void _shareGroup() {
  late SalesFixture f;
  setUp(() => f = SalesFixture());

  Future<String> posted() async {
    final p = await f.addProduct(selling: '10');
    await f.stockUp(p.id, '5');
    final d = await f.draft([SalesLineInput(productId: p.id, quantity: '1')]);
    return (await f.post(d.id)).valueOrNull!.id;
  }

  test('shares the PDF of a posted invoice', () async {
    final id = await posted();
    final r = await f.shareInvoice(id);
    expect(r.isSuccess, isTrue);
    expect(f.renderer.lastLayout!.meta.first.value, 'INV-000001');
    expect(f.sharer.shared.single.fileName, 'INV-000001.pdf');
    expect(f.sharer.shared.single.subject, 'Invoice INV-000001');
    expect(f.sharer.shared.single.size, 4);
    expect(f.renderer.lastLayout!.businessName, 'Test Traders');
  });

  test('a voided invoice can still be shared', () async {
    final id = await posted();
    await f.voidSale(id, reason: 'x');
    expect((await f.shareInvoice(id)).isSuccess, isTrue);
    expect(f.renderer.lastLayout!.statusNote, 'VOID: x');
  });

  test('drafts and unknown invoices cannot be shared', () async {
    final p = await f.addProduct(selling: '10');
    await f.stockUp(p.id, '5');
    final d = await f.draft([SalesLineInput(productId: p.id, quantity: '1')]);
    expect((await f.shareInvoice(d.id)).isFailure, isTrue);
    expect((await f.shareInvoice('nope')).isFailure, isTrue);
    expect(f.sharer.shared, isEmpty);
  });

  test('renderer and sharer failures are passed on', () async {
    final id = await posted();
    f.renderer.failure = const UnexpectedFailure('pdf broke');
    expect((await f.shareInvoice(id)).failureOrNull, isA<UnexpectedFailure>());
    f.renderer.failure = null;
    f.sharer.failure = const UnexpectedFailure('no share');
    expect((await f.shareInvoice(id)).isFailure, isTrue);
  });
}
