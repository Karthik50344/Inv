import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_detail_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_form_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_methods_cubit.dart';
import 'package:inventrix/features/payments/presentation/bloc/payments_bloc.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/fakes.dart';
import '../../support/payment_fakes.dart';

class _FailingSettings extends FakeSettingsRepository {
  @override
  Future<Result<CurrencyConfig>> getCurrencyConfig() async =>
      const Result.failure(DatabaseFailure('settings down'));
}

void main() {
  late PaymentFixture f;

  setUp(() => f = PaymentFixture());

  PaymentFormCubit form() => PaymentFormCubit(
    parties: PartyDirectory(customers: f.customers, suppliers: f.suppliers),
    methods: f.methods,
    openInvoices: f.open,
    recordPayment: f.record,
    settings: f.settings,
    ids: f.ids,
    clock: f.clock,
  );

  PaymentDetailCubit detail() => PaymentDetailCubit(
    payments: f.payments,
    openInvoices: f.open,
    reversePayment: f.reverse,
    recordRefund: f.refund,
    allocateCredit: f.allocate,
    settings: f.settings,
    ids: f.ids,
    clock: f.clock,
  );

  group('PaymentFormCubit', () {
    test('loads parties, methods and open invoices', () async {
      f.addSale('i1', '100');
      final c = form();
      await c.load(type: PartyType.customer, partyId: 'c1');
      expect(c.state.status, PaymentFormStatus.ready);
      expect(c.state.methodId, 'cash');
      expect(c.state.invoices.length, 1);
      expect(c.state.partyLocked, isTrue);
      await c.close();
    });

    test('pre-fills the amount and allocation for one invoice', () async {
      f.addSale('i1', '100');
      f.addSale('i2', '40');
      final c = form();
      await c.load(type: PartyType.customer, partyId: 'c1', invoiceId: 'i2');
      expect(c.state.amount, '40.00');
      expect(c.state.allocations, {'i2': '40.00'});
      await c.close();
    });

    test('auto-allocates oldest first and shows the credit', () async {
      f.addSale('old', '60', date: DateTime.utc(2026, 1, 1));
      f.addSale('new', '60', date: DateTime.utc(2026, 2, 1));
      final c = form();
      await c.load(type: PartyType.customer, partyId: 'c1');
      c.setAmount('150');
      expect(c.state.allocations, {'old': '60.00', 'new': '60.00'});
      expect(c.state.unallocated, f.money('30'));
      c.setAmount('70');
      expect(c.state.allocations, {'old': '60.00', 'new': '10.00'});
      await c.close();
    });

    test('a manual allocation switches auto-allocation off', () async {
      f.addSale('i1', '100');
      final c = form();
      await c.load(type: PartyType.customer, partyId: 'c1');
      c.setAmount('100');
      c.setAllocation('i1', '25');
      c.setAmount('90');
      expect(c.state.autoAllocate, isFalse);
      expect(c.state.allocations, {'i1': '25'});
      await c.close();
    });

    test('saves once, even when submitted twice', () async {
      f.addSale('i1', '100');
      final c = form();
      await c.load(type: PartyType.customer, partyId: 'c1');
      c.setAmount('100');
      await Future.wait([c.submit(), c.submit()]);
      expect(c.state.status, PaymentFormStatus.saved);
      expect(c.state.saved!.number, 'PAY-000001');
      expect(f.payments.items.length, 1);
      await c.close();
    });

    test('validates before saving', () async {
      final c = form();
      await c.load(type: PartyType.customer);
      await c.submit();
      expect(c.state.fieldErrors.keys, containsAll(['party', 'amount']));
      expect(f.payments.items, isEmpty);
      await c.close();
    });

    test('shows the domain error and stays editable', () async {
      f.addSale('i1', '100');
      final c = form();
      await c.load(type: PartyType.customer, partyId: 'c1');
      c.setAmount('200');
      c.setAllocation('i1', '200');
      await c.submit();
      expect(c.state.status, PaymentFormStatus.ready);
      expect(c.state.message, isNotNull);
      expect(f.payments.items, isEmpty);
      await c.close();
    });

    test('supplier form lists suppliers and purchases', () async {
      f.addPurchase('b1', '80');
      final c = form();
      await c.load(type: PartyType.supplier);
      await c.selectParty('s1');
      expect(c.state.invoices.single.id, 'b1');
      c.setAmount('80');
      await c.submit();
      expect(c.state.saved!.isMoneyIn, isFalse);
      await c.close();
    });

    test('fails to load when settings fail', () async {
      final c = PaymentFormCubit(
        parties: PartyDirectory(customers: f.customers, suppliers: f.suppliers),
        methods: f.methods,
        openInvoices: f.open,
        recordPayment: f.record,
        settings: _FailingSettings(),
        ids: f.ids,
        clock: f.clock,
      );
      await c.load(type: PartyType.customer);
      expect(c.state.status, PaymentFormStatus.failure);
      await c.close();
    });
  });

  group('PaymentDetailCubit', () {
    test('loads a payment with its credit and open invoices', () async {
      f.addSale('i1', '100');
      final p = (await f.pay('150', to: {'i1': '50'})).valueOrNull!;
      f.addSale('i2', '30');
      final c = detail();
      await c.load(p.id);
      expect(c.state.status, DetailStatus.loaded);
      expect(c.state.position!.credit, f.money('100'));
      expect(c.state.canAllocate, isTrue);
      expect(c.state.canRefund, isTrue);
      expect(c.state.canReverse, isTrue);
      await c.close();
    });

    test('unknown payment is not found', () async {
      final c = detail();
      await c.load('nope');
      expect(c.state.status, DetailStatus.notFound);
      await c.close();
    });

    test('reverse reloads and disables further actions', () async {
      final p = (await f.pay('10')).valueOrNull!;
      final c = detail();
      await c.load(p.id);
      expect(await c.reverse('Mistake'), isTrue);
      expect(c.state.payment!.isReversed, isTrue);
      expect(c.state.canReverse, isFalse);
      expect(c.state.message, 'Payment reversed.');
      await c.close();
    });

    test('reverse needs a reason', () async {
      final p = (await f.pay('10')).valueOrNull!;
      final c = detail();
      await c.load(p.id);
      expect(await c.reverse(' '), isFalse);
      expect(c.state.payment!.isActive, isTrue);
      await c.close();
    });

    test('refund and credit allocation work through the cubit', () async {
      f.addSale('i1', '100');
      final p = (await f.pay('150', to: {'i1': '100'})).valueOrNull!;
      final c = detail();
      await c.load(p.id);
      expect(await c.refund(amount: '20', reason: 'Overpaid'), isTrue);
      expect(c.state.refunds.length, 1);
      expect(c.state.position!.credit, f.money('30'));
      f.addSale('i2', '30');
      await c.load(p.id);
      expect(await c.allocateCredit({'i2': '30'}), isTrue);
      expect(c.state.position!.credit, f.money('0'));
      expect(c.state.canAllocate, isFalse);
      await c.close();
    });

    test('refund rejects a bad amount without calling the use case', () async {
      final p = (await f.pay('10')).valueOrNull!;
      final c = detail();
      await c.load(p.id);
      expect(await c.refund(amount: 'abc', reason: 'x'), isFalse);
      expect(f.payments.items.length, 1);
      await c.close();
    });

    test('a refund shows no further refund or credit actions', () async {
      final p = (await f.pay('50')).valueOrNull!;
      final r = (await f.doRefund(p.id, '10')).valueOrNull!;
      final c = detail();
      await c.load(r.id);
      expect(c.state.payment!.kind, PaymentKind.refund);
      expect(c.state.canRefund, isFalse);
      expect(c.state.canAllocate, isFalse);
      expect(c.state.canReverse, isTrue);
      await c.close();
    });
  });

  group('PaymentsBloc', () {
    test('loads, filters and searches', () async {
      await f.pay('10');
      await f.pay('20', type: PartyType.supplier);
      final bloc = PaymentsBloc(payments: f.payments)
        ..add(const PaymentsStarted());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.items.length, 2);
      bloc.add(const PaymentsPartyTypeChanged(PartyType.supplier));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.items.single.partyName, 'Bolt Supplies');
      bloc.add(const PaymentsPartyTypeChanged(null));
      bloc.add(const PaymentsSearchChanged('zzz'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, ViewStatus.empty);
      await bloc.close();
    });

    test('hides reversed payments on request', () async {
      final p = (await f.pay('10')).valueOrNull!;
      await f.reverse(p.id, reason: 'x');
      final bloc = PaymentsBloc(payments: f.payments)
        ..add(const PaymentsReversedToggled(show: false));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.status, ViewStatus.empty);
      await bloc.close();
    });
  });

  group('Balance cubits', () {
    test('outstanding total sums only what is owed', () async {
      f.addSale('i1', '100');
      f.addCustomer('c2', 'Zed');
      f.addSale('i2', '50', customerId: 'c2');
      final c = OutstandingCubit(getBalance: f.balances);
      await c.load(PartyType.customer);
      expect(c.state.balances.length, 2);
      expect(c.state.total, f.money('150'));
      await c.close();
    });

    test('empty when nobody owes anything', () async {
      final c = OutstandingCubit(getBalance: f.balances);
      await c.load(PartyType.supplier);
      expect(c.state.status, ViewStatus.empty);
      await c.close();
    });

    test('party balance and invoice settlement cards', () async {
      f.addSale('i1', '100');
      await f.pay('40', to: {'i1': '40'});
      final b = PartyBalanceCubit(getBalance: f.balances);
      await b.load(PartyType.customer, 'c1');
      expect(b.state.balance!.balance, f.money('60'));
      final s = InvoiceSettlementCubit(openInvoices: f.open);
      await s.load(InvoiceKind.sales, 'i1');
      expect(s.state.view!.invoice.outstanding, f.money('60'));
      await s.load(InvoiceKind.sales, 'missing');
      expect(s.state.status, ViewStatus.failure);
      await b.close();
      await s.close();
    });
  });

  group('PaymentMethodsCubit', () {
    test('creates, rejects duplicates, archives', () async {
      final c = PaymentMethodsCubit(
        methods: f.methods,
        createMethod: f.createMethod,
        setArchived: f.archiveMethod,
      );
      await c.load();
      expect(c.state.methods.length, 1);
      expect(await c.create('UPI'), isNull);
      expect(await c.create('upi'), isNotNull);
      final id = c.state.methods.firstWhere((m) => m.name == 'UPI').id;
      await c.setArchived(id, archived: true);
      expect(c.state.methods.firstWhere((m) => m.id == id).isArchived, isTrue);
      await c.close();
    });
  });
}
