import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/domain/entities/payment_status.dart';
import 'package:inventrix/features/payments/domain/services/allocation_planner.dart';
import 'package:inventrix/features/payments/domain/services/payment_status_calculator.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

Money m(String t) =>
    Money.tryParse(t, currencyCode: 'INR', decimalPlaces: 2)!;

PaymentStatus? status({
  String total = '100',
  String paid = '0',
  String refunded = '0',
  DateTime? due,
  DocumentStatus doc = DocumentStatus.posted,
}) => PaymentStatusCalculator.derive(
  documentStatus: doc,
  total: m(total),
  netPaid: m(paid),
  refunded: m(refunded),
  dueDate: due,
  now: DateTime.utc(2026, 3, 10, 15),
);

OpenInvoice invoice(String id, String total, String paid, DateTime date) =>
    OpenInvoice(
      kind: InvoiceKind.sales,
      id: id,
      partyId: 'c1',
      partyName: 'Acme',
      documentStatus: DocumentStatus.posted,
      number: id,
      invoiceDate: date,
      total: m(total),
      netPaid: m(paid),
      refunded: m('0'),
      returned: m('0'),
      returnRefunded: m('0'),
    );

void main() {
  group('PaymentStatusCalculator', () {
    test('unpaid, partially paid and paid', () {
      expect(status(), PaymentStatus.unpaid);
      expect(status(paid: '40'), PaymentStatus.partiallyPaid);
      expect(status(paid: '100'), PaymentStatus.paid);
      expect(status(paid: '100.01'), PaymentStatus.paid);
    });

    test('a zero total is paid', () {
      expect(status(total: '0'), PaymentStatus.paid);
    });

    test('overdue only while something is outstanding and past due', () {
      final past = DateTime.utc(2026, 3, 9);
      expect(status(due: past), PaymentStatus.overdue);
      expect(status(paid: '40', due: past), PaymentStatus.overdue);
      expect(status(paid: '100', due: past), PaymentStatus.paid);
    });

    test('due today is not overdue yet', () {
      expect(
        status(due: DateTime.utc(2026, 3, 10, 0, 1)),
        PaymentStatus.unpaid,
      );
      expect(status(due: DateTime.utc(2026, 3, 11)), PaymentStatus.unpaid);
    });

    test('refunds', () {
      expect(status(refunded: '100'), PaymentStatus.refunded);
      expect(
        status(paid: '60', refunded: '40'),
        PaymentStatus.partiallyRefunded,
      );
    });

    test('only posted documents have a payment status', () {
      for (final doc in [
        DocumentStatus.draft,
        DocumentStatus.cancelled,
        DocumentStatus.voided,
      ]) {
        expect(status(doc: doc), isNull);
      }
    });

    test('written off is never derived', () {
      expect(PaymentStatus.writtenOff.isSettled, isTrue);
      expect(
        [
          status(),
          status(paid: '40'),
          status(paid: '100'),
          status(refunded: '100'),
        ],
        isNot(contains(PaymentStatus.writtenOff)),
      );
    });
  });

  group('OpenInvoice', () {
    test('outstanding never goes below zero', () {
      expect(
        invoice('a', '100', '100.50', DateTime.utc(2026)).outstanding,
        m('0'),
      );
      expect(
        invoice('a', '100', '30', DateTime.utc(2026)).outstanding,
        m('70'),
      );
    });
  });

  group('AllocationPlanner.oldestFirst', () {
    final invoices = [
      invoice('new', '50', '0', DateTime.utc(2026, 3, 5)),
      invoice('old', '80', '30', DateTime.utc(2026, 2, 1)),
      invoice('done', '10', '10', DateTime.utc(2026, 1, 1)),
    ];

    test('fills the oldest first and skips settled invoices', () {
      final plan = AllocationPlanner.oldestFirst(invoices, m('60'));
      expect(plan.map((r) => r.invoiceId).toList(), ['old', 'new']);
      expect(plan.map((r) => r.amount).toList(), [m('50'), m('10')]);
    });

    test('leaves the rest unallocated', () {
      final plan = AllocationPlanner.oldestFirst(invoices, m('500'));
      expect(plan.length, 2);
      expect(plan.first.amount, m('50'));
      expect(plan.last.amount, m('50'));
    });

    test('a small payment covers part of the oldest only', () {
      final plan = AllocationPlanner.oldestFirst(invoices, m('0.01'));
      expect(plan.length, 1);
      expect(plan.single.amount, m('0.01'));
    });
  });
}
