import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/customers/domain/usecases/create_customer.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/usecases/get_open_invoices.dart';
import 'package:inventrix/features/payments/domain/usecases/record_payment.dart';
import 'package:inventrix/features/payments/presentation/pages/outstanding_page.dart';
import 'package:inventrix/features/payments/presentation/pages/payment_detail_page.dart';
import 'package:inventrix/features/payments/presentation/pages/payments_page.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

/// Widget tests for the payment screens. (Written without a Flutter SDK:
/// not yet executed.)
void main() {
  late TestWiring wiring;
  late String customerId;

  Money inr(String t) =>
      Money.tryParse(t, currencyCode: 'INR', decimalPlaces: 2)!;

  void addPostedSale(String id, String total) {
    final t = inr(total);
    final zero = inr('0');
    final now = wiring.clock.now();
    wiring.salesInvoices.items[id] = SalesInvoice(
      id: id,
      number: 'INV-$id',
      customerId: customerId,
      customerName: 'Asha Traders',
      status: DocumentStatus.posted,
      invoiceDate: DateTime.utc(2026, 1, 5),
      lines: const [],
      totals: SalesTotals(
        gross: t,
        discount: zero,
        net: t,
        tax: zero,
        total: t,
      ),
      createdAt: now,
      updatedAt: now,
      postedAt: now,
    );
  }

  setUp(() async {
    wiring = TestWiring();
    wiring.paymentMethods.items['cash'] = PaymentMethod(
      id: 'cash',
      name: 'Cash',
      createdAt: wiring.clock.now(),
    );
    customerId = (await wiring.locator<CreateCustomer>()(
      const PartyDraft(name: 'Asha Traders'),
    )).valueOrNull!.id;
  });

  testWidgets('shows an empty state', (tester) async {
    await pumpInventrix(tester, wiring, location: '/more/payments');
    expect(find.byType(PaymentsPage), findsOneWidget);
    expect(find.text('No payments'), findsOneWidget);
  });

  testWidgets('receives a payment for an invoice and lists it', (tester) async {
    addPostedSale('i1', '100');
    final router = await pumpInventrix(
      tester,
      wiring,
      location: '/more/payments',
    );
    router.push(
      '/more/payments/new?type=customer&party=$customerId&invoice=i1',
    );
    await tester.pumpAndSettle();
    final amount = tester.widget<TextField>(
      find.byKey(const Key('payment_amount')),
    );
    expect(amount.controller!.text, '100.00');
    await tapKey(tester, 'save_payment');
    await tester.pumpAndSettle();
    expect(wiring.payments.items.length, 1);
    expect(find.byType(PaymentsPage), findsOneWidget);
    expect(find.textContaining('PAY-000001'), findsOneWidget);
    final view = (await wiring.locator<GetOpenInvoices>().settlementOf(
      PartyType.customer.invoiceKind,
      'i1',
    )).valueOrNull!;
    expect(view.invoice.outstanding, inr('0'));
  });

  testWidgets('refuses an amount above what is outstanding', (tester) async {
    addPostedSale('i1', '100');
    final router = await pumpInventrix(
      tester,
      wiring,
      location: '/more/payments',
    );
    router.push(
      '/more/payments/new?type=customer&party=$customerId&invoice=i1',
    );
    await tester.pumpAndSettle();
    await enter(tester, 'payment_amount', '150');
    await tester.pumpAndSettle();
    await tapKey(tester, 'save_payment');
    await tester.pumpAndSettle();
    expect(wiring.payments.items, isEmpty);
  });

  testWidgets('a payment can be reversed with a reason', (tester) async {
    addPostedSale('i1', '100');
    final payment = (await wiring.locator<RecordPayment>()(
      RecordPaymentInput(
        partyType: PartyType.customer,
        partyId: customerId,
        methodId: 'cash',
        amount: inr('100'),
        paymentDate: DateTime.utc(2026, 1, 6),
        idempotencyKey: 'k1',
        allocations: [AllocationRequest(invoiceId: 'i1', amount: inr('100'))],
      ),
    )).valueOrNull!;
    await pumpInventrix(
      tester,
      wiring,
      location: '/more/payments/${payment.id}',
    );
    expect(find.byType(PaymentDetailPage), findsOneWidget);
    await tapKey(tester, 'reverse_payment');
    await tester.pumpAndSettle();
    await enter(tester, 'reverse_reason', 'Cheque bounced');
    await tapKey(tester, 'confirm_reverse');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reversed_banner')), findsOneWidget);
    expect(wiring.payments.items[payment.id]!.isReversed, isTrue);
  });

  testWidgets('outstanding balances list who owes money', (tester) async {
    addPostedSale('i1', '100');
    await pumpInventrix(tester, wiring, location: '/more/payments/outstanding');
    expect(find.byType(OutstandingPage), findsOneWidget);
    expect(find.byKey(Key('balance_$customerId')), findsOneWidget);
    expect(find.byKey(const Key('outstanding_total')), findsOneWidget);
  });

  testWidgets('the posted sale shows its payment status', (tester) async {
    addPostedSale('i1', '100');
    await pumpInventrix(tester, wiring, location: '/sales/i1');
    expect(find.byKey(const Key('payment_status_unpaid')), findsOneWidget);
    expect(find.byKey(const Key('record_payment_for_invoice')), findsOneWidget);
  });
}
