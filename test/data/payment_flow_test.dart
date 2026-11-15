import '../core/database/database_test_helpers.dart';
import '../support/fakes.dart';
import 'data_test_support.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/customers/data/repositories/drift_customer_repository.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/payments/data/repositories/drift_payment_method_repository.dart';
import 'package:inventrix/features/payments/data/repositories/drift_payment_repository.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_filter.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/entities/payment_status.dart';
import 'package:inventrix/features/payments/domain/services/allocation_checker.dart';
import 'package:inventrix/features/payments/domain/services/invoice_ledger.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/payments/domain/usecases/get_open_invoices.dart';
import 'package:inventrix/features/payments/domain/usecases/get_party_balance.dart';
import 'package:inventrix/features/payments/domain/usecases/record_payment.dart';
import 'package:inventrix/features/payments/domain/usecases/record_refund.dart';
import 'package:inventrix/features/payments/domain/usecases/reverse_payment.dart';
import 'package:inventrix/features/purchases/data/repositories/drift_purchase_repository.dart';
import 'package:inventrix/features/returns/data/repositories/drift_return_repository.dart';
import 'package:inventrix/features/sales/data/repositories/drift_sales_repository.dart';
import 'package:inventrix/features/suppliers/data/repositories/drift_supplier_repository.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/data/drift_document_sequence_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Audit repository whose writes can be made to fail, to prove rollback.
class _FlakyAudit implements AuditLogRepository {
  _FlakyAudit(this.inner);

  final AuditLogRepository inner;
  bool fail = false;

  @override
  Future<Result<void>> record(AuditEntry entry) async => fail
      ? const Result.failure(DatabaseFailure('audit down'))
      : inner.record(entry);

  @override
  Future<Result<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) => inner.forEntity(entityType, entityId, limit: limit);
}

/// End-to-end payment tests on a real in-memory SQLite database.
/// (Written without a Flutter SDK: not yet executed.)
void main() {
  late DataHarness h;
  late DriftPaymentRepository payments;
  late _FlakyAudit audit;
  late RecordPayment record;
  late RecordRefund refund;
  late ReversePayment reverse;
  late GetPartyBalance balances;
  late GetOpenInvoices open;
  late DriftSalesRepository sales;
  var keyCounter = 0;

  Money inr(String t) =>
      Money.tryParse(t, currencyCode: 'INR', decimalPlaces: 2)!;

  Future<int> count(String table) async => (await h.db
      .customSelect('SELECT COUNT(*) AS c FROM $table')
      .getSingle())
      .read<int>('c');

  setUp(() async {
    h = DataHarness();
    await h.db.initialize();
    final customers = DriftCustomerRepository(h.db, h.settings);
    final suppliers = DriftSupplierRepository(h.db, h.settings);
    final now = t0;
    await customers.create(
      Customer(
        id: 'c1',
        name: 'Acme',
        openingBalance: inr('0'),
        createdAt: now,
        updatedAt: now,
      ),
    );
    await insertSalesInvoice(
      h.db,
      'i1',
      customerId: 'c1',
      status: 'posted',
      number: 'INV-000001',
      postedAt: 5,
      totalMinor: 10000,
      netMinor: 10000,
      taxMinor: 0,
    );
    sales = DriftSalesRepository(h.db, h.settings);
    final purchases = DriftPurchaseRepository(h.db, h.settings);
    payments = DriftPaymentRepository(h.db);
    final methods = DriftPaymentMethodRepository(h.db);
    audit = _FlakyAudit(DriftAuditLogRepository(h.db));
    final tx = DriftTransactionRunner(h.db);
    final sequences = DriftDocumentSequenceRepository(h.db);
    final ids = SequentialIds();
    final clock = FakeClock();
    final parties = PartyDirectory(customers: customers, suppliers: suppliers);
    final returns = DriftReturnRepository(h.db);
    final ledger = InvoiceLedger(
      sales: sales,
      purchases: purchases,
      payments: payments,
      returns: returns,
    );
    record = RecordPayment(
      payments: payments,
      methods: methods,
      parties: parties,
      allocations: AllocationChecker(ledger),
      settings: h.settings,
      sequences: sequences,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    refund = RecordRefund(
      payments: payments,
      methods: methods,
      sequences: sequences,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    reverse = ReversePayment(
      payments: payments,
      ledger: ledger,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    balances = GetPartyBalance(
      parties: parties,
      sales: sales,
      purchases: purchases,
      payments: payments,
      returns: returns,
      settings: h.settings,
    );
    open = GetOpenInvoices(ledger: ledger, payments: payments, clock: clock);
  });

  tearDown(() async => h.close());

  Future<Result<dynamic>> pay(String amount, {String? to, String? key}) =>
      record(
        RecordPaymentInput(
          partyType: PartyType.customer,
          partyId: 'c1',
          methodId: 'pm-cash',
          amount: inr(amount),
          paymentDate: DateTime.utc(2026, 2, 10),
          idempotencyKey: key ?? 'k${++keyCounter}',
          allocations: [
            if (to != null)
              AllocationRequest(invoiceId: 'i1', amount: inr(to)),
          ],
        ),
      );

  test('records, settles and reads back a payment', () async {
    final r = await pay('100', to: '100');
    expect(r.isSuccess, isTrue);
    expect(await count('payments'), 1);
    expect(await count('payment_allocations'), 1);
    final view = (await open.settlementOf(InvoiceKind.sales, 'i1')).valueOrNull!;
    expect(view.status, PaymentStatus.paid);
    expect(view.payments.single.number, 'PAY-000001');
    final b = (await balances(PartyType.customer, 'c1')).valueOrNull!;
    expect(b.balance, inr('0'));
  });

  test('partial payments leave the rest outstanding', () async {
    await pay('30', to: '30');
    final view = (await open.settlementOf(InvoiceKind.sales, 'i1')).valueOrNull!;
    expect(view.status, PaymentStatus.partiallyPaid);
    expect(view.invoice.outstanding, inr('70'));
  });

  test('over-allocation is rejected and writes nothing', () async {
    await pay('70', to: '70');
    final r = await pay('50', to: '50');
    expect(r.failureOrNull, isA<ValidationFailure>());
    expect(await count('payments'), 1);
  });

  test('the same idempotency key never records twice', () async {
    await pay('40', to: '40', key: 'same');
    await pay('40', to: '40', key: 'same');
    expect(await count('payments'), 1);
    expect(await count('payment_allocations'), 1);
  });

  test('a failing audit write rolls back payment, allocations and number',
      () async {
    audit.fail = true;
    final r = await pay('100', to: '100');
    expect(r.failureOrNull, isA<DatabaseFailure>());
    expect(await count('payments'), 0);
    expect(await count('payment_allocations'), 0);
    audit.fail = false;
    final again = await pay('100', to: '100');
    expect(again.valueOrNull.number, 'PAY-000001');
  });

  test('reversal keeps the record and reopens the invoice', () async {
    final p = (await pay('100', to: '100')).valueOrNull;
    expect((await reverse(p.id as String, reason: 'Bounced')).isSuccess, isTrue);
    expect(await count('payments'), 1);
    expect(await count('payment_reversals'), 1);
    final view = (await open.settlementOf(InvoiceKind.sales, 'i1')).valueOrNull!;
    expect(view.status, PaymentStatus.unpaid);
    expect((await balances(PartyType.customer, 'c1')).valueOrNull!.balance,
        inr('100'));
    expect((await reverse(p.id as String, reason: 'again')).isFailure, isTrue);
  });

  test('refunds reopen the invoice and are listed in the history', () async {
    final p = (await pay('100', to: '100')).valueOrNull;
    final r = await refund(
      RecordRefundInput(
        paymentId: p.id as String,
        amount: inr('40'),
        refundDate: DateTime.utc(2026, 2, 11),
        reason: 'Goods returned',
        idempotencyKey: 'rk1',
        reductions: [AllocationRequest(invoiceId: 'i1', amount: inr('40'))],
      ),
    );
    expect(r.valueOrNull!.number, 'RFD-000001');
    final view = (await open.settlementOf(InvoiceKind.sales, 'i1')).valueOrNull!;
    expect(view.status, PaymentStatus.partiallyRefunded);
    final history = (await payments.search(const PaymentFilter())).valueOrNull!;
    expect(history.length, 2);
    final onlyRefunds = (await payments.search(
      const PaymentFilter(partyType: PartyType.customer, query: 'rfd'),
    )).valueOrNull!;
    expect(onlyRefunds.single.isRefund, isTrue);
  });

  test('the void guard reports payment activity', () async {
    expect(
      (await payments.hasActivePayments(InvoiceKind.sales, 'i1')).valueOrNull,
      isFalse,
    );
    final p = (await pay('10', to: '10')).valueOrNull;
    expect(
      (await payments.hasActivePayments(InvoiceKind.sales, 'i1')).valueOrNull,
      isTrue,
    );
    await reverse(p.id as String, reason: 'x');
    expect(
      (await payments.hasActivePayments(InvoiceKind.sales, 'i1')).valueOrNull,
      isFalse,
    );
  });

  test('the database itself refuses an over-allocation', () async {
    final p = (await pay('100')).valueOrNull;
    final failure = await failureOf(
      () => h.db.customStatement(
        'INSERT INTO payment_allocations (id, payment_id, sales_invoice_id, '
        "invoice_number, amount_minor, created_at) "
        "VALUES ('x', ?, 'i1', 'N', 10001, 1)",
        [p.id],
      ),
    );
    expect(failure, isA<DatabaseFailure>());
  });

  test('sales repository still works with the extra tables', () async {
    expect((await sales.getById('i1')).isSuccess, isTrue);
  });
}
