import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import '../../support/return_fakes.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  late ReturnFixture f;
  setUp(() => f = ReturnFixture());

  Future<int> onHand(String productId) async =>
      (await f.inventory.getBalance(productId)).valueOrNull!.quantityOnHand.milli;

  group('sales return', () {
    test('restocks at the original cost and credits the invoice', () async {
      final p = await f.stockedProduct(stock: '10', cost: '40');
      final sale = await f.postedSale({p.id: '4'}); // 400.00, cost 160.00
      expect(await onHand(p.id), 6000);
      final r = await f.doReturn(InvoiceKind.sales, sale.id, {
        sale.lines.first.id: '1',
      });
      final doc = r.valueOrNull!;
      expect(doc.number, 'SRN-000001');
      expect(doc.total, inr(10000));
      expect(doc.lines.single.stockCost, inr(4000));
      expect(doc.lines.single.restocked, isTrue);
      expect(await onHand(p.id), 7000);
      final value = (await f.inventory.getBalance(p.id)).valueOrNull!;
      expect(value.inventoryValue, inr(28000)); // 6*40 + 40
      final moves = (await f.inventory.movementsForSource('sales_return', doc.id))
          .valueOrNull!;
      expect(moves.single.type, StockMovementType.salesReturn);
    });

    test('damaged goods: no stock movement, still credited', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '2'});
      final r = await f.doReturn(
        InvoiceKind.sales,
        sale.id,
        {sale.lines.first.id: '1'},
        noRestock: {sale.lines.first.id},
      );
      expect(r.valueOrNull!.lines.single.restocked, isFalse);
      expect(r.valueOrNull!.stockValue, inr(0));
      expect(await onHand(p.id), 8000);
      expect(r.valueOrNull!.total, inr(10000));
    });

    test('cannot return more than was sold, across several returns', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '3'});
      final id = sale.lines.first.id;
      expect((await f.doReturn(InvoiceKind.sales, sale.id, {id: '2'})).isSuccess,
          isTrue);
      final over = await f.doReturn(InvoiceKind.sales, sale.id, {id: '2'});
      expect(over.failureOrNull, isA<ValidationFailure>());
      expect(over.failureOrNull!.message, contains('Only 1'));
      expect((await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'})).isSuccess,
          isTrue);
      final more = await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'});
      expect(more.isFailure, isTrue);
    });

    test('returns of a line add up exactly to the line (tax, rounding)', () async {
      f.addTaxRate();
      final p = await f.stockedProduct(
        selling: '33.33',
        taxRateId: 'gst18',
        stock: '10',
        cost: '10',
      );
      final sale = await f.postedSale({p.id: '3'});
      final id = sale.lines.first.id;
      var net = inr(0);
      var tax = inr(0);
      var cost = inr(0);
      for (var i = 0; i < 3; i++) {
        final d = (await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'}))
            .valueOrNull!;
        net += d.net;
        tax += d.tax;
        cost += d.stockValue;
      }
      expect(net, sale.lines.first.net);
      expect(tax, sale.lines.first.tax);
      expect(cost, inr(3000));
      expect(await onHand(p.id), 10000);
    });

    test('uneven tax: separate returns still add up to the line', () async {
      f.addTaxRate();
      final p = await f.stockedProduct(
        selling: '10.01',
        taxRateId: 'gst18',
        stock: '10',
        cost: '10',
      );
      final sale = await f.postedSale({p.id: '3'});
      final line = sale.lines.first;
      var tax = inr(0);
      for (var i = 0; i < 3; i++) {
        tax += (await f.doReturn(InvoiceKind.sales, sale.id, {line.id: '1'}))
            .valueOrNull!
            .tax;
      }
      expect(line.tax.minorUnits, isNot(equals(line.tax.minorUnits ~/ 3 * 3)));
      expect(tax, line.tax);
    });

    test('validation: reason, empty, bad quantity, unit precision', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '2'});
      final id = sale.lines.first.id;
      expect((await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'}, reason: ' '))
          .failureOrNull, isA<ValidationFailure>());
      expect((await f.doReturn(InvoiceKind.sales, sale.id, {id: ''}))
          .failureOrNull!.message, contains('at least one'));
      expect((await f.doReturn(InvoiceKind.sales, sale.id, {id: '1.5'}))
          .failureOrNull, isA<ValidationFailure>());
      expect((await f.doReturn(InvoiceKind.sales, sale.id, {id: '-1'}))
          .failureOrNull, isA<ValidationFailure>());
      expect((await f.doReturn(InvoiceKind.sales, sale.id, {'nope': '1'}))
          .failureOrNull, isA<ValidationFailure>());
      expect(await onHand(p.id), 8000);
    });

    test('date before the invoice is rejected', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '1'});
      final r = await f.doReturn(InvoiceKind.sales, sale.id,
          {sale.lines.first.id: '1'}, date: DateTime.utc(2025, 12, 1));
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('only posted invoices can be returned', () async {
      final p = await f.stockedProduct();
      final d = await f.draft([SalesLineInput(productId: p.id, quantity: '1')]);
      final r = await f.doReturn(InvoiceKind.sales, d.id, {'x': '1'});
      expect(r.failureOrNull!.message, contains('Only posted'));
    });

    test('same idempotency key posts once', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '3'});
      final id = sale.lines.first.id;
      final a = await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'}, key: 'k');
      final b = await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'}, key: 'k');
      expect(b.valueOrNull!.id, a.valueOrNull!.id);
      expect(f.returns.items.length, 1);
      expect(await onHand(p.id), 8000);
    });

    test('rolls back stock and number when the insert fails', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '3'});
      f.returns.insertFailure = const DatabaseFailure('disk');
      final r = await f.doReturn(
          InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'});
      expect(r.isFailure, isTrue);
      expect(await onHand(p.id), 7000);
      expect(f.returns.items, isEmpty);
      f.returns.insertFailure = null;
      final ok = await f.doReturn(
          InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'});
      expect(ok.valueOrNull!.number, 'SRN-000001');
    });

    test('audit entry written', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '1'});
      await f.doReturn(InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'});
      expect(f.audit.entries.any((e) => e.entityType == 'sales_return'), isTrue);
    });
  });

  group('refund and credit (sales)', () {
    test('credit lowers what is owed', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'}); // 400
      await f.doReturn(InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'});
      final open = (await f.ledger.get(InvoiceKind.sales, sale.id)).valueOrNull!;
      expect(open.outstanding, inr(30000));
      final bal = (await f.balances.call(PartyType.customer, 'c1')).valueOrNull!;
      expect(bal.balance, inr(30000));
    });

    test('cash refund only for money paid beyond what is owed', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'}); // 400
      await f.receive('400', sale.id);
      final id = sale.lines.first.id;
      final tooMuch = await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'},
          refund: '150', methodId: 'cash');
      expect(tooMuch.failureOrNull!.message, contains('At most 100.00'));
      final noMethod =
          await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'}, refund: '100');
      expect(noMethod.failureOrNull, isA<ValidationFailure>());
      final ok = await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'},
          refund: '100', methodId: 'cash');
      expect(ok.valueOrNull!.refund!.amount, inr(10000));
      expect(ok.valueOrNull!.credit, inr(0));
      final open = (await f.ledger.get(InvoiceKind.sales, sale.id)).valueOrNull!;
      expect(open.outstanding, inr(0));
      expect(open.credit, inr(0));
      expect((await f.balances.call(PartyType.customer, 'c1')).valueOrNull!.balance, inr(0));
    });

    test('paid invoice returned without refund leaves customer credit', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'});
      await f.receive('400', sale.id);
      await f.doReturn(InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'});
      final bal = (await f.balances.call(PartyType.customer, 'c1')).valueOrNull!;
      expect(bal.balance, inr(-10000));
      expect(bal.hasCredit, isTrue);
      final open = (await f.ledger.get(InvoiceKind.sales, sale.id)).valueOrNull!;
      expect(open.credit, inr(10000));
    });

    test('partly paid invoice: refund only what exceeds what is owed', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'}); // 400
      await f.receive('150', sale.id);
      final id = sale.lines.first.id;
      // After returning 100 the customer still owes 300 but paid only 150.
      final refused = await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'},
          refund: '100', methodId: 'cash');
      expect(refused.failureOrNull, isA<ValidationFailure>());
      // Returning 3 leaves 100 owed against 150 paid: 50 may go back.
      final ok = await f.doReturn(InvoiceKind.sales, sale.id, {id: '3'},
          refund: '50', methodId: 'cash');
      expect(ok.valueOrNull!.refundAmount, inr(5000));
      expect(ok.valueOrNull!.credit, inr(25000));
      final open = (await f.ledger.get(InvoiceKind.sales, sale.id)).valueOrNull!;
      expect(open.outstanding, inr(0));
      expect(open.credit, inr(0));
    });

    test('unpaid invoice: nothing to refund in cash', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'});
      final r = await f.doReturn(InvoiceKind.sales, sale.id,
          {sale.lines.first.id: '1'}, refund: '10', methodId: 'cash');
      expect(r.failureOrNull!.message, contains('nothing to refund'));
    });

    test('walk-in return hands the whole value back', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '2'}, customerId: null);
      final noMethod = await f.doReturn(
          InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'});
      expect(noMethod.failureOrNull!.message, contains('how the money'));
      final r = await f.doReturn(
          InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'},
          methodId: 'upi');
      expect(r.valueOrNull!.refund!.amount, inr(10000));
      expect(r.valueOrNull!.isWalkIn, isTrue);
    });

    test('archived refund method rejected', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'});
      await f.receive('400', sale.id);
      f.methods.items['cash'] = PaymentMethod(
        id: 'cash',
        name: 'Cash',
        createdAt: f.clock.now(),
        archivedAt: f.clock.now(),
      );
      final r = await f.doReturn(InvoiceKind.sales, sale.id,
          {sale.lines.first.id: '1'}, refund: '100', methodId: 'cash');
      expect(r.failureOrNull!.message, contains('archived'));
    });
  });

  group('purchase return', () {
    test('removes stock at average cost and reduces payable', () async {
      final p = await f.stockedProduct(stock: '0', cost: '0');
      final bill = await f.postedPurchase({p.id: '10'}, unitPrice: '40'); // 400
      expect(await onHand(p.id), 10000);
      final r = await f.doReturn(
          InvoiceKind.purchase, bill.id, {bill.lines.first.id: '3'});
      final doc = r.valueOrNull!;
      expect(doc.number, 'PRN-000001');
      expect(doc.total, inr(12000));
      expect(doc.stockValue, inr(12000));
      expect(await onHand(p.id), 7000);
      final open = (await f.ledger.get(InvoiceKind.purchase, bill.id)).valueOrNull!;
      expect(open.outstanding, inr(28000));
    });

    test('rejected when the goods are no longer in stock', () async {
      final p = await f.stockedProduct(stock: '0', cost: '0');
      final bill = await f.postedPurchase({p.id: '5'});
      await f.postedSale({p.id: '4'});
      final r = await f.doReturn(
          InvoiceKind.purchase, bill.id, {bill.lines.first.id: '3'});
      expect(r.failureOrNull, isA<InsufficientStockFailure>());
      expect(f.returns.items, isEmpty);
      expect(await onHand(p.id), 1000);
    });

    test('supplier refund within what was paid', () async {
      final p = await f.stockedProduct(stock: '0', cost: '0');
      final bill = await f.postedPurchase({p.id: '10'});
      await f.payTo('400', bill.id);
      final id = bill.lines.first.id;
      final r = await f.doReturn(InvoiceKind.purchase, bill.id, {id: '2'},
          refund: '80', methodId: 'cash');
      expect(r.valueOrNull!.refundAmount, inr(8000));
      final bal = (await f.balances.call(PartyType.supplier, 's1')).valueOrNull!;
      expect(bal.balance, inr(0));
    });
  });

  group('guards', () {
    test('returned invoices cannot be voided', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '2'});
      await f.doReturn(InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'});
      final v = await f.voidSaleGuarded(sale.id, reason: 'oops');
      expect(v.failureOrNull!.message, contains('returns'));
    });

    test('returned purchases cannot be voided', () async {
      final p = await f.stockedProduct(stock: '0', cost: '0');
      final bill = await f.postedPurchase({p.id: '5'});
      await f.doReturn(InvoiceKind.purchase, bill.id, {bill.lines.first.id: '1'});
      final v = await f.voidPurchaseGuarded(bill.id, reason: 'oops');
      expect(v.failureOrNull!.message, contains('returns'));
    });

    test('ledger and balances reconcile after returns', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'});
      await f.doReturn(InvoiceKind.sales, sale.id, {sale.lines.first.id: '2'});
      await f.doReturn(InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'},
          noRestock: {sale.lines.first.id});
      final report = (await f.reconcile()).valueOrNull!;
      expect(report.isConsistent, isTrue);
    });
  });
}
