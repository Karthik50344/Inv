import 'fakes.dart';
import 'inventory_fakes.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/services/allocation_checker.dart';
import 'package:inventrix/features/payments/domain/services/invoice_ledger.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/payments/domain/usecases/get_party_balance.dart';
import 'package:inventrix/features/payments/domain/usecases/record_payment.dart';
import 'package:inventrix/features/payments/domain/usecases/reverse_payment.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/services/purchase_line_builder.dart';
import 'package:inventrix/features/purchases/domain/usecases/post_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/save_purchase_draft.dart';
import 'package:inventrix/features/purchases/domain/usecases/void_purchase.dart';
import 'package:inventrix/features/returns/domain/entities/return_document.dart';
import 'package:inventrix/features/returns/domain/entities/return_filter.dart';
import 'package:inventrix/features/returns/domain/entities/return_input.dart';
import 'package:inventrix/features/returns/domain/entities/return_summary.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/features/returns/domain/services/returnable_invoice_loader.dart';
import 'package:inventrix/features/returns/domain/usecases/post_return.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/usecases/void_sale.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/services/invoice_return_lookup.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'payment_fakes.dart';
import 'purchase_fakes.dart';
import 'sales_fakes.dart';

/// Lookup and guard for tests that do not involve returns: no invoice ever
/// has returns.
final class NoReturns implements InvoiceReturnLookup, InvoiceReturnGuard {
  /// Creates the stand-in.
  const NoReturns();

  @override
  Future<Result<Map<String, InvoiceReturnTotals>>> totalsFor(
    InvoiceKind kind,
    Iterable<String> invoiceIds,
  ) async => const Result.success({});

  @override
  Future<Result<PartyReturnTotals>> partyTotals(
    InvoiceKind kind,
    String partyId, {
    required String currencyCode,
    required int decimalPlaces,
  }) async => const Result.success(PartyReturnTotals.none);

  @override
  Future<Result<bool>> hasReturns(InvoiceKind kind, String invoiceId) async =>
      const Result.success(false);
}

/// In-memory returns store that emulates the SQL rules: unique number and
/// idempotency key, append-only rows.
class FakeReturnRepository
    implements
        ReturnRepository,
        InvoiceReturnLookup,
        InvoiceReturnGuard,
        Rollbackable {
  Map<String, ReturnDocument> items = {};
  Failure? insertFailure;

  String _key(InvoiceKind kind, String id) => '${kind.name}:$id';

  @override
  Object snapshot() => Map<String, ReturnDocument>.of(items);

  @override
  void restore(Object snapshot) => items = Map<String, ReturnDocument>.of(
    snapshot as Map<String, ReturnDocument>,
  );

  @override
  Future<Result<List<ReturnSummary>>> search(ReturnFilter filter) async {
    final q = filter.query.toLowerCase();
    final list = items.values.where((d) {
      if (filter.kind != null && d.kind != filter.kind) return false;
      if (filter.invoiceId != null && d.invoiceId != filter.invoiceId) {
        return false;
      }
      return q.isEmpty ||
          d.number.toLowerCase().contains(q) ||
          d.invoiceNumber.toLowerCase().contains(q) ||
          d.partyName.toLowerCase().contains(q);
    }).toList()..sort((a, b) {
      final byDate = b.returnDate.compareTo(a.returnDate);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
    return Result.success([
      for (final d in list)
        ReturnSummary(
          id: d.id,
          kind: d.kind,
          number: d.number,
          invoiceId: d.invoiceId,
          invoiceNumber: d.invoiceNumber,
          partyName: d.partyName,
          returnDate: d.returnDate,
          total: d.total,
          refundAmount: d.refundAmount,
          lineCount: d.lines.length,
        ),
    ]);
  }

  @override
  Future<Result<ReturnDocument>> getById(InvoiceKind kind, String id) async =>
      items[_key(kind, id)] == null
      ? const Result.failure(NotFoundFailure('Return not found.'))
      : Result.success(items[_key(kind, id)]!);

  @override
  Future<Result<ReturnDocument?>> findByIdempotencyKey(
    InvoiceKind kind,
    String key,
  ) async {
    for (final d in items.values) {
      if (d.kind == kind && d.idempotencyKey == key) {
        return Result.success(d);
      }
    }
    return const Result.success(null);
  }

  @override
  Future<Result<List<ReturnDocument>>> forInvoice(
    InvoiceKind kind,
    String invoiceId,
  ) async => Result.success(
    items.values
        .where((d) => d.kind == kind && d.invoiceId == invoiceId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
  );

  @override
  Future<Result<void>> insert(ReturnDocument document) async {
    if (insertFailure != null) return Result.failure(insertFailure!);
    final clash = items.values.any(
      (d) =>
          d.kind == document.kind &&
          (d.number == document.number ||
              d.idempotencyKey == document.idempotencyKey),
    );
    if (clash) {
      return const Result.failure(DuplicateEntryFailure('duplicate return'));
    }
    items[_key(document.kind, document.id)] = document;
    return const Result.success(null);
  }

  @override
  Future<Result<Map<String, InvoiceReturnTotals>>> totalsFor(
    InvoiceKind kind,
    Iterable<String> invoiceIds,
  ) async {
    final wanted = invoiceIds.toSet();
    final result = <String, InvoiceReturnTotals>{};
    for (final d in items.values.where((d) => d.kind == kind)) {
      if (!wanted.contains(d.invoiceId)) continue;
      final old = result[d.invoiceId] ?? InvoiceReturnTotals.none;
      result[d.invoiceId] = InvoiceReturnTotals(
        returnedMinor: old.returnedMinor + d.total.minorUnits,
        refundedMinor: old.refundedMinor + d.refundAmount.minorUnits,
        count: old.count + 1,
      );
    }
    return Result.success(result);
  }

  @override
  Future<Result<PartyReturnTotals>> partyTotals(
    InvoiceKind kind,
    String partyId, {
    required String currencyCode,
    required int decimalPlaces,
  }) async {
    var returned = 0;
    var refunded = 0;
    for (final d in items.values) {
      if (d.kind != kind || d.partyId != partyId) continue;
      if (d.total.currencyCode != currencyCode) continue;
      returned += d.total.minorUnits;
      refunded += d.refundAmount.minorUnits;
    }
    return Result.success(
      PartyReturnTotals(returnedMinor: returned, refundedMinor: refunded),
    );
  }

  @override
  Future<Result<bool>> hasReturns(InvoiceKind kind, String invoiceId) async =>
      Result.success(
        items.values.any((d) => d.kind == kind && d.invoiceId == invoiceId),
      );
}

/// Wires sales, purchases, payments and returns on one shared stock ledger,
/// numbering sequence and transaction.
class ReturnFixture extends SalesFixture {
  ReturnFixture() {
    purchases = FakePurchaseRepository();
    suppliers = FakeSupplierRepository();
    returns = FakeReturnRepository();
    payments = FakePaymentRepository();
    methods = FakePaymentMethodRepository();
    methods.items['cash'] = PaymentMethod(
      id: 'cash',
      name: 'Cash',
      createdAt: clock.now(),
    );
    methods.items['upi'] = PaymentMethod(
      id: 'upi',
      name: 'UPI',
      createdAt: clock.now(),
    );
    tx = FakeTransactionRunner([
      inventory,
      audit,
      sales,
      purchases,
      sequences,
      returns,
      payments,
    ]);
    purchaseLineBuilder = PurchaseLineBuilder(
      products: products,
      units: units,
      taxRates: taxRates,
    );
    savePurchaseDraft = SavePurchaseDraft(
      purchases: purchases,
      suppliers: suppliers,
      lineBuilder: purchaseLineBuilder,
      settings: settings,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    postPurchase = PostPurchase(
      purchases: purchases,
      suppliers: suppliers,
      products: products,
      inventory: inventory,
      sequences: sequences,
      settings: settings,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    ledger = InvoiceLedger(
      sales: sales,
      purchases: purchases,
      payments: payments,
      returns: returns,
    );
    loader = ReturnableInvoiceLoader(
      sales: sales,
      purchases: purchases,
      returns: returns,
      ledger: ledger,
      inventory: inventory,
    );
    postReturn = PostReturn(
      loader: loader,
      returns: returns,
      inventory: inventory,
      methods: methods,
      sequences: sequences,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    final parties = PartyDirectory(customers: customers, suppliers: suppliers);
    recordPayment = RecordPayment(
      payments: payments,
      methods: methods,
      parties: parties,
      allocations: AllocationChecker(ledger),
      settings: settings,
      sequences: sequences,
      audit: audit,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    reversePayment = ReversePayment(
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
      settings: settings,
    );
    voidSaleGuarded = VoidSale(
      sales: sales,
      inventory: inventory,
      audit: audit,
      payments: payments,
      returns: returns,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    voidPurchaseGuarded = VoidPurchase(
      purchases: purchases,
      inventory: inventory,
      audit: audit,
      payments: payments,
      returns: returns,
      transactions: tx,
      ids: ids,
      clock: clock,
    );
    suppliers.items['s1'] = Supplier(
      id: 's1',
      name: 'Bolt Supplies',
      openingBalance: Money.zero(currencyCode: 'INR', decimalPlaces: 2),
      createdAt: clock.now(),
      updatedAt: clock.now(),
    );
  }

  late final FakePurchaseRepository purchases;
  late final FakeSupplierRepository suppliers;
  late final FakeReturnRepository returns;
  late final FakePaymentRepository payments;
  late final FakePaymentMethodRepository methods;
  late final FakeTransactionRunner tx;
  late final PurchaseLineBuilder purchaseLineBuilder;
  late final SavePurchaseDraft savePurchaseDraft;
  late final PostPurchase postPurchase;
  late final InvoiceLedger ledger;
  late final ReturnableInvoiceLoader loader;
  late final PostReturn postReturn;
  late final RecordPayment recordPayment;
  late final ReversePayment reversePayment;
  late final GetPartyBalance balances;
  late final VoidSale voidSaleGuarded;
  late final VoidPurchase voidPurchaseGuarded;

  int _keys = 0;

  /// An INR amount from text such as `'100.50'`.
  Money money(String text) =>
      Money.tryParse(text, currencyCode: 'INR', decimalPlaces: 2)!;

  /// Creates a product that sells at [selling] and has [stock] on hand
  /// bought at [cost].
  Future<Product> stockedProduct({
    String name = 'Widget',
    String selling = '100',
    String stock = '10',
    String cost = '40',
    String? taxRateId,
    bool inclusive = false,
    String unitId = 'pcs',
  }) async {
    final product = await addTaxedProduct(
      name: name,
      selling: selling,
      taxRateId: taxRateId,
      inclusive: inclusive,
      unitId: unitId,
    );
    if (stock != '0') {
      await stockUp(product.id, stock, unitCost: cost);
    }
    return product;
  }

  /// Posts a sale of [lines] (product id -> quantity) and returns it.
  Future<SalesInvoice> postedSale(
    Map<String, String> lines, {
    String? customerId = 'c1',
    Map<String, String> prices = const {},
  }) async {
    final invoice = await draft([
      for (final e in lines.entries)
        SalesLineInput(
          productId: e.key,
          quantity: e.value,
          unitPrice: prices[e.key] ?? '',
        ),
    ], customerId: customerId);
    final posted = await post(invoice.id);
    return posted.valueOrNull!;
  }

  /// Posts a purchase of [lines] (product id -> quantity) from supplier `s1`.
  Future<PurchaseInvoice> postedPurchase(
    Map<String, String> lines, {
    String unitPrice = '40',
  }) async {
    final saved = await savePurchaseDraft(
      PurchaseDraftInput(
        supplierId: 's1',
        invoiceDate: DateTime.utc(2026, 1, 5),
        lines: [
          for (final e in lines.entries)
            PurchaseLineInput(
              productId: e.key,
              quantity: e.value,
              unitPrice: unitPrice,
            ),
        ],
      ),
    );
    final draftInvoice = saved.valueOrNull;
    if (draftInvoice == null) {
      throw StateError('Purchase draft rejected: ${saved.failureOrNull}');
    }
    final posted = await postPurchase(draftInvoice.id);
    return posted.valueOrNull!;
  }

  /// Posts a return of [lines] (invoice line id -> quantity).
  Future<Result<ReturnDocument>> doReturn(
    InvoiceKind kind,
    String invoiceId,
    Map<String, String> lines, {
    String reason = 'Customer changed mind',
    String refund = '',
    String? methodId,
    Set<String> noRestock = const {},
    String? key,
    DateTime? date,
  }) => postReturn(
    ReturnInput(
      kind: kind,
      invoiceId: invoiceId,
      returnDate: date ?? DateTime.utc(2026, 1, 10),
      reason: reason,
      idempotencyKey: key ?? 'rkey-${++_keys}',
      refundAmount: refund,
      refundMethodId: methodId,
      lines: [
        for (final e in lines.entries)
          ReturnLineInput(
            invoiceLineId: e.key,
            quantity: e.value,
            restock: !noRestock.contains(e.key),
          ),
      ],
    ),
  );

  /// Records a customer receipt allocated to sale [invoiceId].
  Future<Result<Payment>> receive(String amount, String invoiceId) =>
      recordPayment(
        RecordPaymentInput(
          partyType: PartyType.customer,
          partyId: 'c1',
          methodId: 'cash',
          amount: money(amount),
          paymentDate: DateTime.utc(2026, 1, 8),
          idempotencyKey: 'pay-${++_keys}',
          allocations: [
            AllocationRequest(invoiceId: invoiceId, amount: money(amount)),
          ],
        ),
      );

  /// Records a payment to supplier `s1` allocated to purchase [invoiceId].
  Future<Result<Payment>> payTo(String amount, String invoiceId) =>
      recordPayment(
        RecordPaymentInput(
          partyType: PartyType.supplier,
          partyId: 's1',
          methodId: 'cash',
          amount: money(amount),
          paymentDate: DateTime.utc(2026, 1, 8),
          idempotencyKey: 'pay-${++_keys}',
          allocations: [
            AllocationRequest(invoiceId: invoiceId, amount: money(amount)),
          ],
        ),
      );
}
