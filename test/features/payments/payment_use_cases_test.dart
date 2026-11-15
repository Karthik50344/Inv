import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';
import 'package:inventrix/features/payments/domain/entities/payment_position.dart';
import 'package:inventrix/features/payments/domain/entities/payment_status.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import '../../support/payment_fakes.dart';

void main() {
  late PaymentFixture f;

  setUp(() => f = PaymentFixture());

  Future<PaymentStatus?> statusOf(String id) async {
    final view = (await f.open.settlementOf(InvoiceKind.sales, id)).valueOrNull!;
    return view.status;
  }

  group('RecordPayment', () {
    test('full payment settles the invoice', () async {
      f.addSale('i1', '100');
      final result = await f.pay('100', to: {'i1': '100'});
      final p = result.valueOrNull!;
      expect(p.number, 'PAY-000001');
      expect(p.kind, PaymentKind.payment);
      expect(p.isMoneyIn, isTrue);
      expect(p.allocations.length, 1);
      expect(p.partyName, 'Acme Traders');
      expect(p.methodName, 'Cash');
      expect(await statusOf('i1'), PaymentStatus.paid);
    });

    test('partial payment leaves the rest outstanding', () async {
      f.addSale('i1', '100');
      await f.pay('40', to: {'i1': '40'});
      final view = (await f.open.settlementOf(InvoiceKind.sales, 'i1'))
          .valueOrNull!;
      expect(view.status, PaymentStatus.partiallyPaid);
      expect(view.invoice.outstanding, f.money('60'));
      expect(view.payments.length, 1);
    });

    test('one payment can settle several invoices', () async {
      f.addSale('i1', '100');
      f.addSale('i2', '50');
      final p = (await f.pay('150', to: {'i1': '100', 'i2': '50'})).valueOrNull!;
      expect(p.allocations.length, 2);
      expect(p.allocatedTotal, f.money('150'));
      expect(await statusOf('i2'), PaymentStatus.paid);
    });

    test('unallocated remainder stays as credit', () async {
      f.addSale('i1', '100');
      final p = (await f.pay('130', to: {'i1': '100'})).valueOrNull!;
      expect(PaymentPosition.of(p, const []).credit, f.money('30'));
    });

    test('a payment without allocations is all credit', () async {
      final p = (await f.pay('75')).valueOrNull!;
      expect(p.allocations, isEmpty);
      expect(PaymentPosition.of(p, const []).credit, f.money('75'));
    });

    test('supplier payment is money out and settles purchases', () async {
      f.addPurchase('b1', '200');
      final p = (await f.pay(
        '200',
        type: PartyType.supplier,
        to: {'b1': '200'},
      )).valueOrNull!;
      expect(p.isMoneyIn, isFalse);
      final view = (await f.open.settlementOf(InvoiceKind.purchase, 'b1'))
          .valueOrNull!;
      expect(view.status, PaymentStatus.paid);
    });

    test('rejects over-allocation of an invoice', () async {
      f.addSale('i1', '100');
      final r = await f.pay('150', to: {'i1': '150'});
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.payments.items, isEmpty);
    });

    test('rejects over-allocation across two payments', () async {
      f.addSale('i1', '100');
      await f.pay('70', to: {'i1': '70'});
      final r = await f.pay('50', to: {'i1': '50'});
      expect(r.failureOrNull, isA<ValidationFailure>());
      expect(f.payments.items.length, 1);
    });

    test('rejects allocations larger than the payment', () async {
      f.addSale('i1', '100');
      f.addSale('i2', '100');
      final r = await f.pay('120', to: {'i1': '100', 'i2': '100'});
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('rejects zero and negative amounts', () async {
      expect((await f.pay('0')).failureOrNull, isA<ValidationFailure>());
      final r = await f.record(
        RecordPaymentInput(
          partyType: PartyType.customer,
          partyId: 'c1',
          methodId: 'cash',
          amount: f.money('10').negate(),
          paymentDate: DateTime.utc(2026, 3, 10),
          idempotencyKey: 'neg',
        ),
      );
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('rejects drafts, voided invoices and other parties', () async {
      f.addSale('d', '100', status: DocumentStatus.draft);
      f.addSale('v', '100', status: DocumentStatus.voided);
      f.addSale('walk', '100', customerId: null);
      expect((await f.pay('10', to: {'d': '10'})).isFailure, isTrue);
      expect((await f.pay('10', to: {'v': '10'})).isFailure, isTrue);
      expect((await f.pay('10', to: {'walk': '10'})).isFailure, isTrue);
      expect((await f.pay('10', to: {'nope': '10'})).failureOrNull,
          isA<NotFoundFailure>());
      f.addPurchase('b1', '100');
      expect((await f.pay('10', to: {'b1': '10'})).isFailure, isTrue);
    });

    test('rejects an archived method and unknown party', () async {
      await f.archiveMethod('cash', archived: true);
      expect((await f.pay('10')).failureOrNull, isA<ValidationFailure>());
      await f.archiveMethod('cash', archived: false);
      f.customers.items.clear();
      expect((await f.pay('10')).failureOrNull, isA<NotFoundFailure>());
    });

    test('rejects a currency other than the configured one', () async {
      final r = await f.record(
        RecordPaymentInput(
          partyType: PartyType.customer,
          partyId: 'c1',
          methodId: 'cash',
          amount: Money.fromMinor(1000, currencyCode: 'USD', decimalPlaces: 2),
          paymentDate: DateTime.utc(2026, 3, 10),
          idempotencyKey: 'usd',
        ),
      );
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('the same key never records twice', () async {
      f.addSale('i1', '100');
      final a = await f.pay('40', to: {'i1': '40'}, key: 'same');
      final b = await f.pay('40', to: {'i1': '40'}, key: 'same');
      expect(b.valueOrNull!.id, a.valueOrNull!.id);
      expect(f.payments.items.length, 1);
      expect(f.sequences.counters['payment'], 1);
      final view = (await f.open.settlementOf(InvoiceKind.sales, 'i1'))
          .valueOrNull!;
      expect(view.invoice.netPaid, f.money('40'));
    });

    test('a reused key with a different request is rejected', () async {
      await f.pay('40', key: 'k');
      final r = await f.pay('50', key: 'k');
      expect(r.failureOrNull, isA<ValidationFailure>());
    });

    test('rolls back everything when the write fails', () async {
      f.addSale('i1', '100');
      f.payments.insertFailure = const DatabaseFailure('disk full');
      final r = await f.pay('100', to: {'i1': '100'});
      expect(r.failureOrNull, isA<DatabaseFailure>());
      expect(f.payments.items, isEmpty);
      expect(f.sequences.counters['payment'] ?? 0, 0);
      expect(f.audit.entries, isEmpty);
      expect(f.tx.rolledBack, 1);
    });

    test('numbers are gap free and an audit entry is written', () async {
      final a = (await f.pay('1')).valueOrNull!;
      final b = (await f.pay('2')).valueOrNull!;
      expect([a.number, b.number], ['PAY-000001', 'PAY-000002']);
      expect(f.audit.entries.length, 2);
      expect(f.audit.entries.first.action, 'recorded');
    });
  });

  group('AllocatePaymentCredit', () {
    test('applies credit to a later invoice', () async {
      final p = (await f.pay('100')).valueOrNull!;
      f.addSale('i1', '60');
      final r = await f.allocate(p.id, [
        AllocationRequest(invoiceId: 'i1', amount: f.money('60')),
      ]);
      expect(r.valueOrNull!.allocations.length, 1);
      expect(await statusOf('i1'), PaymentStatus.paid);
      expect(PaymentPosition.of(r.valueOrNull!, const []).credit, f.money('40'));
    });

    test('cannot exceed the remaining credit, also when repeated', () async {
      final p = (await f.pay('100')).valueOrNull!;
      f.addSale('i1', '80');
      f.addSale('i2', '80');
      expect(
        (await f.allocate(p.id, [
          AllocationRequest(invoiceId: 'i1', amount: f.money('80')),
        ])).isSuccess,
        isTrue,
      );
      final again = await f.allocate(p.id, [
        AllocationRequest(invoiceId: 'i2', amount: f.money('80')),
      ]);
      expect(again.failureOrNull, isA<ValidationFailure>());
      final sameInvoice = await f.allocate(p.id, [
        AllocationRequest(invoiceId: 'i1', amount: f.money('20')),
      ]);
      expect(sameInvoice.failureOrNull, isA<ValidationFailure>());
    });

    test('rejects reversed payments and empty requests', () async {
      final p = (await f.pay('100')).valueOrNull!;
      expect((await f.allocate(p.id, [])).isFailure, isTrue);
      await f.reverse(p.id, reason: 'mistake');
      f.addSale('i1', '10');
      final r = await f.allocate(p.id, [
        AllocationRequest(invoiceId: 'i1', amount: f.money('10')),
      ]);
      expect(r.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('ReversePayment', () {
    test('reopens the invoice but keeps the payment record', () async {
      f.addSale('i1', '100');
      final p = (await f.pay('100', to: {'i1': '100'})).valueOrNull!;
      final r = await f.reverse(p.id, reason: 'Cheque bounced');
      expect(r.valueOrNull!.isReversed, isTrue);
      expect(f.payments.items.containsKey(p.id), isTrue);
      expect(await statusOf('i1'), PaymentStatus.unpaid);
      final balance = (await f.balances(PartyType.customer, 'c1')).valueOrNull!;
      expect(balance.payments, f.money('0'));
      expect(balance.balance, f.money('100'));
    });

    test('requires a reason and cannot be repeated', () async {
      final p = (await f.pay('10')).valueOrNull!;
      expect((await f.reverse(p.id, reason: ' ')).failureOrNull,
          isA<ValidationFailure>());
      expect((await f.reverse(p.id, reason: 'x')).isSuccess, isTrue);
      expect((await f.reverse(p.id, reason: 'x')).failureOrNull,
          isA<ValidationFailure>());
      expect(f.audit.entries.where((e) => e.action == 'reversed').length, 1);
    });

    test('a payment with an active refund must keep it reversed first',
        () async {
      f.addSale('i1', '100');
      final p = (await f.pay('100', to: {'i1': '100'})).valueOrNull!;
      final refund = (await f.doRefund(p.id, '30', from: {'i1': '30'}))
          .valueOrNull!;
      expect((await f.reverse(p.id, reason: 'x')).failureOrNull,
          isA<ValidationFailure>());
      expect((await f.reverse(refund.id, reason: 'undo')).isSuccess, isTrue);
      expect((await f.reverse(p.id, reason: 'x')).isSuccess, isTrue);
    });

    test('a refund cannot be reversed once the invoice was paid again',
        () async {
      f.addSale('i1', '100');
      final p = (await f.pay('100', to: {'i1': '100'})).valueOrNull!;
      final refund = (await f.doRefund(p.id, '40', from: {'i1': '40'}))
          .valueOrNull!;
      await f.pay('40', to: {'i1': '40'});
      expect((await f.reverse(refund.id, reason: 'undo')).failureOrNull,
          isA<ValidationFailure>());
    });

    test('unknown payment is not found', () async {
      expect((await f.reverse('zzz', reason: 'x')).failureOrNull,
          isA<NotFoundFailure>());
    });
  });

  group('RecordRefund', () {
    test('taking money back reopens the invoice', () async {
      f.addSale('i1', '100');
      final p = (await f.pay('100', to: {'i1': '100'})).valueOrNull!;
      final r = (await f.doRefund(p.id, '40', from: {'i1': '40'})).valueOrNull!;
      expect(r.number, 'RFD-000001');
      expect(r.kind, PaymentKind.refund);
      expect(r.isMoneyIn, isFalse);
      expect(r.allocations.single.amount, f.money('40').negate());
      final view = (await f.open.settlementOf(InvoiceKind.sales, 'i1'))
          .valueOrNull!;
      expect(view.invoice.netPaid, f.money('60'));
      expect(view.invoice.refunded, f.money('40'));
      expect(view.status, PaymentStatus.partiallyRefunded);
    });

    test('refunding everything makes the invoice refunded', () async {
      f.addSale('i1', '100');
      final p = (await f.pay('100', to: {'i1': '100'})).valueOrNull!;
      await f.doRefund(p.id, '100', from: {'i1': '100'});
      expect(await statusOf('i1'), PaymentStatus.refunded);
    });

    test('refunds unallocated credit without touching invoices', () async {
      f.addSale('i1', '100');
      final p = (await f.pay('130', to: {'i1': '100'})).valueOrNull!;
      expect((await f.doRefund(p.id, '30')).isSuccess, isTrue);
      expect(await statusOf('i1'), PaymentStatus.paid);
      expect((await f.doRefund(p.id, '1')).failureOrNull,
          isA<ValidationFailure>());
    });

    test('cannot refund more than was paid or more than settled', () async {
      f.addSale('i1', '100');
      final p = (await f.pay('100', to: {'i1': '100'})).valueOrNull!;
      expect((await f.doRefund(p.id, '100.01', from: {'i1': '100'})).isFailure,
          isTrue);
      expect((await f.doRefund(p.id, '50', from: {'i1': '60'})).isFailure,
          isTrue);
      expect((await f.doRefund(p.id, '50')).isFailure, isTrue);
      expect((await f.doRefund(p.id, '0', from: {})).isFailure, isTrue);
      await f.doRefund(p.id, '70', from: {'i1': '70'});
      expect((await f.doRefund(p.id, '40', from: {'i1': '40'})).isFailure,
          isTrue);
      expect((await f.doRefund(p.id, '30', from: {'i1': '30'})).isSuccess,
          isTrue);
    });

    test('requires a reason and is idempotent', () async {
      final p = (await f.pay('50')).valueOrNull!;
      final noReason = await f.refund(
        RecordRefundInput(
          paymentId: p.id,
          amount: f.money('10'),
          refundDate: DateTime.utc(2026, 3, 11),
          reason: '',
          idempotencyKey: 'r1',
        ),
      );
      expect(noReason.failureOrNull, isA<ValidationFailure>());
      final a = await f.doRefund(p.id, '10', key: 'same');
      final b = await f.doRefund(p.id, '10', key: 'same');
      expect(b.valueOrNull!.id, a.valueOrNull!.id);
      expect(f.payments.items.length, 2);
    });

    test('cannot refund a refund or a reversed payment', () async {
      final p = (await f.pay('50')).valueOrNull!;
      final r = (await f.doRefund(p.id, '10')).valueOrNull!;
      expect((await f.doRefund(r.id, '5')).isFailure, isTrue);
      await f.reverse(r.id, reason: 'x');
      await f.reverse(p.id, reason: 'x');
      expect((await f.doRefund(p.id, '5')).isFailure, isTrue);
    });
  });

  group('Balances', () {
    test('customer balance = opening + invoices - payments + refunds',
        () async {
      f.addCustomer('c1', 'Acme Traders', opening: '25');
      f.addSale('i1', '100');
      f.addSale('i2', '50');
      f.addSale('draft', '999', status: DocumentStatus.draft);
      final p = (await f.pay('100', to: {'i1': '100'})).valueOrNull!;
      var b = (await f.balances(PartyType.customer, 'c1')).valueOrNull!;
      expect(b.invoiced, f.money('150'));
      expect(b.balance, f.money('75'));
      await f.doRefund(p.id, '20', from: {'i1': '20'});
      b = (await f.balances(PartyType.customer, 'c1')).valueOrNull!;
      expect(b.balance, f.money('95'));
    });

    test('an advance payment shows as credit', () async {
      await f.pay('40');
      final b = (await f.balances(PartyType.customer, 'c1')).valueOrNull!;
      expect(b.balance, f.money('-40'));
      expect(b.hasCredit, isTrue);
    });

    test('supplier payable falls as we pay', () async {
      f.addPurchase('b1', '300');
      await f.pay('100', type: PartyType.supplier, to: {'b1': '100'});
      final b = (await f.balances(PartyType.supplier, 's1')).valueOrNull!;
      expect(b.balance, f.money('200'));
    });

    test('outstanding lists unsettled parties, largest first', () async {
      f.addSale('i1', '100');
      f.addCustomer('c2', 'Zed');
      f.addSale('i2', '500', customerId: 'c2');
      f.addCustomer('c3', 'Settled');
      final list = (await f.balances.outstanding(PartyType.customer))
          .valueOrNull!;
      expect(list.map((b) => b.partyId).toList(), ['c2', 'c1']);
      await f.pay('100', to: {'i1': '100'});
      final after = (await f.balances.outstanding(PartyType.customer))
          .valueOrNull!;
      expect(after.map((b) => b.partyId).toList(), ['c2']);
    });

    test('open invoices exclude settled and walk-in ones', () async {
      f.addSale('i1', '100');
      f.addSale('i2', '50');
      f.addSale('walk', '70', customerId: null);
      await f.pay('50', to: {'i2': '50'});
      final open = (await f.open.forParty(PartyType.customer, 'c1')).valueOrNull!;
      expect(open.map((i) => i.id).toList(), ['i1']);
    });
  });

  group('Voiding invoices with payments', () {
    test('the guard sees payment activity until it is reversed', () async {
      f.addSale('i1', '100');
      expect(
        (await f.payments.hasActivePayments(InvoiceKind.sales, 'i1'))
            .valueOrNull,
        isFalse,
      );
      final p = (await f.pay('10', to: {'i1': '10'})).valueOrNull!;
      expect(
        (await f.payments.hasActivePayments(InvoiceKind.sales, 'i1'))
            .valueOrNull,
        isTrue,
      );
      await f.reverse(p.id, reason: 'x');
      expect(
        (await f.payments.hasActivePayments(InvoiceKind.sales, 'i1'))
            .valueOrNull,
        isFalse,
      );
    });
  });

  group('Payment methods', () {
    test('create, reject duplicates, archive and restore', () async {
      final a = await f.createMethod('Bank transfer');
      expect(a.isSuccess, isTrue);
      expect((await f.createMethod('bank TRANSFER')).failureOrNull,
          isA<ValidationFailure>());
      expect((await f.createMethod('  ')).failureOrNull,
          isA<ValidationFailure>());
      await f.archiveMethod(a.valueOrNull!.id, archived: true);
      expect((await f.methods.list()).valueOrNull!.length, 1);
      expect((await f.createMethod('Bank transfer')).isSuccess, isTrue);
    });
  });
}
