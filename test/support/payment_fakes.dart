import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/payments/domain/entities/invoice_settlement.dart';
import 'package:inventrix/features/payments/domain/entities/party_payment_totals.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_allocation.dart';
import 'package:inventrix/features/payments/domain/entities/payment_filter.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/entities/payment_reversal.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/services/allocation_checker.dart';
import 'package:inventrix/features/payments/domain/services/invoice_ledger.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/payments/domain/usecases/allocate_payment_credit.dart';
import 'package:inventrix/features/payments/domain/usecases/get_open_invoices.dart';
import 'package:inventrix/features/payments/domain/usecases/get_party_balance.dart';
import 'package:inventrix/features/payments/domain/usecases/manage_payment_methods.dart';
import 'package:inventrix/features/payments/domain/usecases/record_payment.dart';
import 'package:inventrix/features/payments/domain/usecases/record_refund.dart';
import 'package:inventrix/features/payments/domain/usecases/reverse_payment.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_totals.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/services/invoice_payment_guard.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import 'fakes.dart';
import 'inventory_fakes.dart';
import 'purchase_fakes.dart';
import 'return_fakes.dart' show NoReturns;
import 'sales_fakes.dart';

/// In-memory payments store that emulates the SQL rules: unique idempotency
/// key, one reversal per payment, append-only rows.
class FakePaymentRepository
    implements PaymentRepository, InvoicePaymentGuard, Rollbackable {
  Map<String, Payment> items = {};
  Failure? insertFailure;

  @override
  Object snapshot() => Map<String, Payment>.of(items);

  @override
  void restore(Object snapshot) =>
      items = Map<String, Payment>.of(snapshot as Map<String, Payment>);

  @override
  Future<Result<Payment?>> findByIdempotencyKey(String key) async {
    for (final p in items.values) {
      if (p.idempotencyKey == key) return Result.success(p);
    }
    return const Result.success(null);
  }

  @override
  Future<Result<Payment>> getById(String id) async => items[id] == null
      ? const Result.failure(NotFoundFailure('Payment not found.'))
      : Result.success(items[id]!);

  @override
  Future<Result<List<Payment>>> search(PaymentFilter f) async {
    final q = f.query.toLowerCase();
    final list = items.values.where((p) {
      if (f.partyType != null && p.partyType != f.partyType) return false;
      if (f.partyId != null && p.partyId != f.partyId) return false;
      if (f.kind != null && p.kind != f.kind) return false;
      if (!f.includeReversed && p.isReversed) return false;
      if (f.invoiceId != null &&
          !p.allocations.any((a) => a.invoiceId == f.invoiceId)) {
        return false;
      }
      return q.isEmpty ||
          p.number.toLowerCase().contains(q) ||
          p.partyName.toLowerCase().contains(q) ||
          (p.reference?.toLowerCase().contains(q) ?? false);
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Result.success(list);
  }

  @override
  Future<Result<List<Payment>>> activeRefundsOf(String paymentId) async =>
      Result.success([
        for (final p in items.values)
          if (p.refundOfPaymentId == paymentId && p.isActive) p,
      ]);

  @override
  Future<Result<void>> insert(Payment payment) async {
    if (insertFailure != null) return Result.failure(insertFailure!);
    if (items.values.any((p) => p.idempotencyKey == payment.idempotencyKey)) {
      return const Result.failure(DuplicateEntryFailure('duplicate key'));
    }
    items[payment.id] = payment;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> insertAllocations(
    List<PaymentAllocation> allocations,
  ) async {
    for (final a in allocations) {
      final p = items[a.paymentId]!;
      items[p.id] = p.copyWith(allocations: [...p.allocations, a]);
    }
    return const Result.success(null);
  }

  @override
  Future<Result<void>> insertReversal(PaymentReversal reversal) async {
    final p = items[reversal.paymentId];
    if (p == null) return const Result.failure(NotFoundFailure('missing'));
    if (p.isReversed) {
      return const Result.failure(DuplicateEntryFailure('already reversed'));
    }
    items[p.id] = p.copyWith(reversal: reversal);
    return const Result.success(null);
  }

  @override
  Future<Result<Map<String, InvoiceSettlement>>> settlements(
    InvoiceKind kind,
    Iterable<String> invoiceIds,
  ) async {
    final wanted = invoiceIds.toSet();
    final net = <String, int>{};
    final refunded = <String, int>{};
    final count = <String, int>{};
    for (final p in items.values.where((p) => p.isActive)) {
      for (final a in p.allocations) {
        if (a.invoiceKind != kind || !wanted.contains(a.invoiceId)) continue;
        net.update(a.invoiceId, (v) => v + a.amount.minorUnits,
            ifAbsent: () => a.amount.minorUnits);
        count.update(a.invoiceId, (v) => v + 1, ifAbsent: () => 1);
        if (a.amount.isNegative) {
          refunded.update(a.invoiceId, (v) => v - a.amount.minorUnits,
              ifAbsent: () => -a.amount.minorUnits);
        }
      }
    }
    return Result.success({
      for (final id in net.keys)
        id: InvoiceSettlement(
          netPaidMinor: net[id]!,
          refundedMinor: refunded[id] ?? 0,
          activeCount: count[id]!,
        ),
    });
  }

  @override
  Future<Result<PartyPaymentTotals>> partyTotals(
    PartyType type,
    String partyId, {
    required String currencyCode,
    required int decimalPlaces,
  }) async {
    var payments = 0;
    var refunds = 0;
    for (final p in items.values) {
      if (!p.isActive ||
          p.partyType != type ||
          p.partyId != partyId ||
          p.amount.currencyCode != currencyCode) {
        continue;
      }
      if (p.kind == PaymentKind.payment) {
        payments += p.amount.minorUnits;
      } else {
        refunds += p.amount.minorUnits;
      }
    }
    return Result.success(
      PartyPaymentTotals(paymentsMinor: payments, refundsMinor: refunds),
    );
  }

  @override
  Future<Result<bool>> hasActivePayments(
    InvoiceKind kind,
    String invoiceId,
  ) async {
    final s = await settlements(kind, [invoiceId]);
    return Result.success((s.valueOrNull![invoiceId]?.activeCount ?? 0) > 0);
  }
}

/// In-memory payment methods.
class FakePaymentMethodRepository implements PaymentMethodRepository {
  final Map<String, PaymentMethod> items = {};

  @override
  Future<Result<List<PaymentMethod>>> list({
    bool includeArchived = false,
  }) async => Result.success([
    for (final m in items.values)
      if (includeArchived || !m.isArchived) m,
  ]..sort((a, b) => a.name.compareTo(b.name)));

  @override
  Future<Result<PaymentMethod>> getById(String id) async => items[id] == null
      ? const Result.failure(NotFoundFailure('Payment method not found.'))
      : Result.success(items[id]!);

  @override
  Future<Result<void>> create(PaymentMethod method) async {
    final clash = items.values.any(
      (m) =>
          !m.isArchived && m.name.toLowerCase() == method.name.toLowerCase(),
    );
    if (clash) return const Result.failure(DuplicateEntryFailure('dup'));
    items[method.id] = method;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> update(PaymentMethod method) async {
    items[method.id] = method;
    return const Result.success(null);
  }
}

/// Wires every payments use case on in-memory fakes with rollback emulation.
class PaymentFixture {
  PaymentFixture() {
    payments = FakePaymentRepository();
    methods = FakePaymentMethodRepository();
    sales = FakeSalesRepository();
    purchases = FakePurchaseRepository();
    customers = FakeCustomerRepository();
    suppliers = FakeSupplierRepository();
    sequences = FakeDocumentSequenceRepository();
    audit = FakeAuditLogRepository();
    tx = FakeTransactionRunner([payments, sequences, audit]);
    final parties = PartyDirectory(customers: customers, suppliers: suppliers);
    ledger = InvoiceLedger(
      sales: sales,
      purchases: purchases,
      payments: payments,
      returns: const NoReturns(),
    );
    final checker = AllocationChecker(ledger);
    record = RecordPayment(
      payments: payments,
      methods: methods,
      parties: parties,
      allocations: checker,
      settings: settings,
      sequences: sequences,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    allocate = AllocatePaymentCredit(
      payments: payments,
      allocations: checker,
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
    refund = RecordRefund(
      payments: payments,
      methods: methods,
      sequences: sequences,
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
      returns: const NoReturns(),
      settings: settings,
    );
    open = GetOpenInvoices(ledger: ledger, payments: payments, clock: clock);
    createMethod = CreatePaymentMethod(
      methods: methods,
      ids: ids,
      clock: clock,
    );
    archiveMethod = SetPaymentMethodArchived(methods: methods, clock: clock);
    final now = clock.now();
    methods.items['cash'] = PaymentMethod(
      id: 'cash',
      name: 'Cash',
      createdAt: now,
    );
    customers.items['c1'] = Customer(
      id: 'c1',
      name: 'Acme Traders',
      openingBalance: money('0'),
      createdAt: now,
      updatedAt: now,
    );
    suppliers.items['s1'] = Supplier(
      id: 's1',
      name: 'Bolt Supplies',
      openingBalance: money('0'),
      createdAt: now,
      updatedAt: now,
    );
  }

  final FakeClock clock = FakeClock(DateTime.utc(2026, 3, 10, 10));
  final SequentialIds ids = SequentialIds();
  final FakeSettingsRepository settings = FakeSettingsRepository();
  late final FakePaymentRepository payments;
  late final FakePaymentMethodRepository methods;
  late final FakeSalesRepository sales;
  late final FakePurchaseRepository purchases;
  late final FakeCustomerRepository customers;
  late final FakeSupplierRepository suppliers;
  late final FakeDocumentSequenceRepository sequences;
  late final FakeAuditLogRepository audit;
  late final FakeTransactionRunner tx;
  late final InvoiceLedger ledger;
  late final RecordPayment record;
  late final AllocatePaymentCredit allocate;
  late final ReversePayment reverse;
  late final RecordRefund refund;
  late final GetPartyBalance balances;
  late final GetOpenInvoices open;
  late final CreatePaymentMethod createMethod;
  late final SetPaymentMethodArchived archiveMethod;

  int _keys = 0;

  /// Adds (or replaces) a customer.
  Customer addCustomer(String id, String name, {String opening = '0'}) {
    final now = clock.now();
    final customer = Customer(
      id: id,
      name: name,
      openingBalance: money(opening),
      createdAt: now,
      updatedAt: now,
    );
    customers.items[id] = customer;
    return customer;
  }

  /// An INR amount from text such as `'100.50'`.
  Money money(String text) => Money.tryParse(
    text,
    currencyCode: 'INR',
    decimalPlaces: 2,
  )!;

  /// Adds a posted sales invoice for [customerId].
  SalesInvoice addSale(
    String id,
    String total, {
    String? customerId = 'c1',
    DateTime? date,
    DateTime? dueDate,
    DocumentStatus status = DocumentStatus.posted,
  }) {
    final t = money(total);
    final zero = money('0');
    final invoice = SalesInvoice(
      id: id,
      number: status == DocumentStatus.draft ? null : 'INV-$id',
      customerId: customerId,
      customerName: 'Acme Traders',
      status: status,
      invoiceDate: date ?? DateTime.utc(2026, 3, 1),
      dueDate: dueDate,
      lines: const [],
      totals: SalesTotals(gross: t, discount: zero, net: t, tax: zero, total: t),
      createdAt: clock.now(),
      updatedAt: clock.now(),
      postedAt: clock.now(),
    );
    sales.items[id] = invoice;
    return invoice;
  }

  /// Adds a posted purchase invoice for supplier `s1`.
  PurchaseInvoice addPurchase(
    String id,
    String total, {
    DateTime? date,
    DateTime? dueDate,
  }) {
    final t = money(total);
    final zero = money('0');
    final invoice = PurchaseInvoice(
      id: id,
      number: 'BILL-$id',
      supplierId: 's1',
      supplierName: 'Bolt Supplies',
      status: DocumentStatus.posted,
      invoiceDate: date ?? DateTime.utc(2026, 3, 1),
      dueDate: dueDate,
      lines: const [],
      totals: PurchaseTotals(
        gross: t,
        discount: zero,
        net: t,
        tax: zero,
        total: t,
      ),
      createdAt: clock.now(),
      updatedAt: clock.now(),
      postedAt: clock.now(),
    );
    purchases.items[id] = invoice;
    return invoice;
  }

  /// Records a customer receipt (or supplier payment) and returns the result.
  Future<Result<Payment>> pay(
    String amount, {
    PartyType type = PartyType.customer,
    Map<String, String> to = const {},
    String? key,
    String methodId = 'cash',
  }) => record(
    RecordPaymentInput(
      partyType: type,
      partyId: type == PartyType.customer ? 'c1' : 's1',
      methodId: methodId,
      amount: money(amount),
      paymentDate: DateTime.utc(2026, 3, 10),
      idempotencyKey: key ?? 'key-${++_keys}',
      allocations: [
        for (final e in to.entries)
          AllocationRequest(invoiceId: e.key, amount: money(e.value)),
      ],
    ),
  );

  /// Refunds [amount] of [paymentId], taking [from] off the given invoices.
  Future<Result<Payment>> doRefund(
    String paymentId,
    String amount, {
    Map<String, String> from = const {},
    String? key,
  }) => refund(
    RecordRefundInput(
      paymentId: paymentId,
      amount: money(amount),
      refundDate: DateTime.utc(2026, 3, 11),
      reason: 'Goods returned',
      idempotencyKey: key ?? 'rkey-${++_keys}',
      reductions: [
        for (final e in from.entries)
          AllocationRequest(invoiceId: e.key, amount: money(e.value)),
      ],
    ),
  );
}
