import 'payment_guard_fake.dart';
import 'dart:typed_data';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/sales/domain/entities/sales_filter.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_summary.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/invoice_layout.dart';
import 'package:inventrix/features/sales/domain/services/invoice_pdf.dart';
import 'package:inventrix/features/sales/domain/services/sales_stock_check.dart';
import 'package:inventrix/features/sales/domain/usecases/share_invoice_pdf.dart';
import 'package:inventrix/features/sales/domain/services/sales_line_builder.dart';
import 'package:inventrix/features/sales/domain/usecases/get_customer_receivable.dart';
import 'package:inventrix/features/sales/domain/usecases/post_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/save_sales_draft.dart';
import 'package:inventrix/features/sales/domain/usecases/transition_sale.dart';
import 'package:inventrix/features/sales/domain/usecases/void_sale.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import 'fakes.dart';
import 'return_fakes.dart' show NoReturns;
import 'inventory_fakes.dart';
import 'purchase_fakes.dart' show FakeDocumentSequenceRepository;
import 'inventory_fixture.dart';

/// In-memory sale repository that emulates the guarded SQL updates.
class FakeSalesRepository implements SalesRepository, Rollbackable {
  Map<String, SalesInvoice> items = {};
  Failure? saveFailure;

  @override
  Object snapshot() => Map<String, SalesInvoice>.of(items);

  @override
  void restore(Object snapshot) => items = Map<String, SalesInvoice>.of(
    snapshot as Map<String, SalesInvoice>,
  );

  @override
  Future<Result<List<SalesSummary>>> search(SalesFilter filter) async {
    final q = filter.query.toLowerCase();
    final list = items.values.where((i) {
      if (filter.status != null && i.status != filter.status) return false;
      if (filter.customerId != null && i.customerId != filter.customerId) {
        return false;
      }
      return q.isEmpty ||
          (i.number?.toLowerCase().contains(q) ?? false) ||
          i.customerName.toLowerCase().contains(q) ||
          (i.customerReference?.toLowerCase().contains(q) ?? false);
    }).toList()..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
    return Result.success([
      for (final i in list)
        SalesSummary(
          id: i.id,
          number: i.number,
          customerId: i.customerId,
          customerName: i.customerName,
          status: i.status,
          invoiceDate: i.invoiceDate,
          dueDate: i.dueDate,
          customerReference: i.customerReference,
          total: i.totals.total,
          lineCount: i.lines.length,
        ),
    ]);
  }

  @override
  Future<Result<SalesInvoice>> getById(String id) async => items[id] == null
      ? const Result.failure(NotFoundFailure('Sales not found.'))
      : Result.success(items[id]!);

  @override
  Future<Result<void>> saveDraft(SalesInvoice invoice) async {
    if (saveFailure != null) return Result.failure(saveFailure!);
    final existing = items[invoice.id];
    if (existing != null && existing.status != DocumentStatus.draft) {
      return const Result.failure(
        ValidationFailure('Only draft sales can be edited.'),
      );
    }
    items[invoice.id] = invoice;
    return const Result.success(null);
  }

  SalesInvoice _copy(
    SalesInvoice i, {
    DocumentStatus? status,
    String? number,
    DateTime? at,
    DateTime? postedAt,
    DateTime? cancelledAt,
    DateTime? voidedAt,
    String? voidReason,
  }) => SalesInvoice(
    id: i.id,
    number: number ?? i.number,
    customerId: i.customerId,
    customerName: i.customerName,
    status: status ?? i.status,
    invoiceDate: i.invoiceDate,
    dueDate: i.dueDate,
    customerReference: i.customerReference,
    notes: i.notes,
    lines: i.lines,
    totals: i.totals,
    createdAt: i.createdAt,
    updatedAt: at ?? i.updatedAt,
    postedAt: postedAt ?? i.postedAt,
    cancelledAt: cancelledAt ?? i.cancelledAt,
    voidedAt: voidedAt ?? i.voidedAt,
    voidReason: voidReason ?? i.voidReason,
  );

  Result<SalesInvoice> _guard(String id, Set<DocumentStatus> from) {
    final i = items[id];
    if (i == null)
      return const Result.failure(NotFoundFailure('Sales not found.'));
    if (!from.contains(i.status)) {
      return const Result.failure(
        ValidationFailure('This sale was changed in the meantime.'),
      );
    }
    return Result.success(i);
  }

  @override
  Future<Result<void>> changeStatus(
    String id, {
    required Set<DocumentStatus> from,
    required DocumentStatus to,
    required DateTime at,
  }) async {
    final found = _guard(id, from);
    final i = found.valueOrNull;
    if (i == null) return Result.failure(found.failureOrNull!);
    items[id] = _copy(
      i,
      status: to,
      at: at,
      cancelledAt: to == DocumentStatus.cancelled ? at : null,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> markPosted(
    String id, {
    required String number,
    required DateTime at,
  }) async {
    final found = _guard(id, {
      DocumentStatus.draft,
      DocumentStatus.created,
      DocumentStatus.approved,
      DocumentStatus.authorized,
    });
    final i = found.valueOrNull;
    if (i == null) return Result.failure(found.failureOrNull!);
    items[id] = _copy(
      i,
      status: DocumentStatus.posted,
      number: number,
      at: at,
      postedAt: at,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> markVoided(
    String id, {
    required String reason,
    required DateTime at,
  }) async {
    final found = _guard(id, {DocumentStatus.posted});
    final i = found.valueOrNull;
    if (i == null) return Result.failure(found.failureOrNull!);
    items[id] = _copy(
      i,
      status: DocumentStatus.voided,
      at: at,
      voidedAt: at,
      voidReason: reason,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<Money>> postedTotalForCustomer(String customerId) async {
    final posted = items.values.where(
      (i) => i.customerId == customerId && i.status == DocumentStatus.posted,
    );
    var sum = Money.zero(currencyCode: 'INR', decimalPlaces: 2);
    for (final i in posted) {
      sum += i.totals.total;
    }
    return Result.success(sum);
  }
}

/// Renderer that records the layout it was given.
class FakeInvoicePdfRenderer implements InvoicePdfRenderer {
  InvoiceLayout? lastLayout;
  Failure? failure;

  @override
  Future<Result<Uint8List>> render(InvoiceLayout layout) async {
    lastLayout = layout;
    return failure == null
        ? Result.success(Uint8List.fromList([37, 80, 68, 70]))
        : Result.failure(failure!);
  }
}

/// Sharer that records what was shared.
class FakeInvoiceFileSharer implements InvoiceFileSharer {
  final List<({String fileName, String subject, int size})> shared = [];
  Failure? failure;

  @override
  Future<Result<void>> share({
    required Uint8List bytes,
    required String fileName,
    required String subject,
  }) async {
    if (failure != null) return Result.failure(failure!);
    shared.add((fileName: fileName, subject: subject, size: bytes.length));
    return const Result.success(null);
  }
}

/// Wires the sale use cases on top of the inventory fixture.
class SalesFixture extends InventoryFixture {
  SalesFixture() {
    sales = FakeSalesRepository();
    sequences = FakeDocumentSequenceRepository();
    customers = FakeCustomerRepository();
    saleTx = FakeTransactionRunner([
      inventory,
      audit,
      sales,
      sequences,
    ]);
    lineBuilder = SalesLineBuilder(
      products: products,
      units: units,
      taxRates: taxRates,
    );
    stockCheck = SalesStockCheck(inventory: inventory);
    saveDraft = SaveSalesDraft(
      sales: sales,
      customers: customers,
      lineBuilder: lineBuilder,
      stockCheck: stockCheck,
      settings: settings,
      audit: audit,
      transactions: saleTx,
      ids: ids,
      clock: clock,
    );
    transition = TransitionSale(
      sales: sales,
      settings: settings,
      audit: audit,
      transactions: saleTx,
      ids: ids,
      clock: clock,
    );
    post = PostSale(
      sales: sales,
      customers: customers,
      products: products,
      inventory: inventory,
      sequences: sequences,
      settings: settings,
      audit: audit,
      transactions: saleTx,
      ids: ids,
      clock: clock,
    );
    voidSale = VoidSale(
      sales: sales,
      inventory: inventory,
      audit: audit,
      payments: guard,
      returns: const NoReturns(),
      transactions: saleTx,
      ids: ids,
      clock: clock,
    );
    receivable = GetCustomerReceivable(sales: sales, customers: customers);
    renderer = FakeInvoicePdfRenderer();
    sharer = FakeInvoiceFileSharer();
    shareInvoice = ShareInvoicePdf(
      sales: sales,
      settings: settings,
      renderer: renderer,
      sharer: sharer,
      formatMoney: (m) => 'INR ${m.toPlainString()}',
      formatDate: (d) => '${d.year}-${d.month}-${d.day}',
    );
    addCustomer();
  }

  final SwitchableGuard guard = SwitchableGuard();
  late final FakeSalesRepository sales;
  late final FakeDocumentSequenceRepository sequences;
  late final FakeCustomerRepository customers;
  late final FakeTransactionRunner saleTx;
  late final SalesLineBuilder lineBuilder;
  late final SalesStockCheck stockCheck;
  late final SaveSalesDraft saveDraft;
  late final TransitionSale transition;
  late final PostSale post;
  late final VoidSale voidSale;
  late final GetCustomerReceivable receivable;
  late final FakeInvoicePdfRenderer renderer;
  late final FakeInvoiceFileSharer sharer;
  late final ShareInvoicePdf shareInvoice;

  Customer addCustomer({String id = 'c1', String name = 'Acme Traders'}) {
    final now = clock.now();
    final customer = Customer(
      id: id,
      name: name,
      openingBalance: Money.zero(currencyCode: 'INR', decimalPlaces: 2),
      createdAt: now,
      updatedAt: now,
    );
    customers.items[id] = customer;
    return customer;
  }

  /// Adds a tax rate directly.
  TaxRate addTaxRate({
    String id = 'gst18',
    String name = 'GST 18%',
    int bp = 1800,
    bool exempt = false,
  }) {
    final now = clock.now();
    final rate = TaxRate(
      id: id,
      name: name,
      rateBp: bp,
      isExempt: exempt,
      createdAt: now,
      updatedAt: now,
    );
    taxRates.items[id] = rate;
    return rate;
  }

  /// Creates a product with tax settings through the real use case.
  Future<Product> addTaxedProduct({
    String name = 'Widget',
    String selling = '100',
    String? taxRateId,
    bool inclusive = false,
    String unitId = 'pcs',
  }) async {
    final result =
        await CreateProduct(
          validator: validator,
          products: products,
          ids: ids,
          clock: clock,
        )(
          ProductDraft(
            name: name,
            unitId: unitId,
            sellingPrice: selling,
            taxRateId: taxRateId,
            priceIncludesTax: inclusive,
          ),
        );
    return result.valueOrNull!;
  }

  /// Receives [quantity] of [productId] into stock at [unitCost] each
  /// (through the real stock-adjustment use case).
  Future<void> stockUp(
    String productId,
    String quantity, {
    String unitCost = '5',
  }) async {
    final result = await adjustStock(
      productId: productId,
      direction: StockAdjustmentDirection.stockIn,
      quantity: quantity,
      reason: 'test stock',
      unitCost: unitCost,
    );
    if (result.failureOrNull != null) {
      throw StateError('Stock-up failed: ${result.failureOrNull}');
    }
  }

  /// Saves a one-customer draft and returns it (fails the test run if
  /// invalid).
  Future<SalesInvoice> draft(
    List<SalesLineInput> lines, {
    String? customerId = 'c1',
    String? id,
  }) async {
    final result = await saveDraft(
      SalesDraftInput(
        id: id,
        customerId: customerId,
        invoiceDate: DateTime.utc(2026, 1, 5),
        lines: lines,
      ),
    );
    final invoice = result.valueOrNull;
    if (invoice == null) {
      throw StateError('Draft rejected: ${result.failureOrNull}');
    }
    return invoice;
  }
}

/// Test-only helper to corrupt a stored invoice's totals.
abstract final class SalesInvoiceTamper {
  static SalesInvoice withTotal(SalesInvoice i, Money total) => SalesInvoice(
    id: i.id,
    number: i.number,
    customerId: i.customerId,
    customerName: i.customerName,
    status: i.status,
    invoiceDate: i.invoiceDate,
    dueDate: i.dueDate,
    customerReference: i.customerReference,
    notes: i.notes,
    lines: i.lines,
    totals: SalesTotals(
      gross: i.totals.gross,
      discount: i.totals.discount,
      net: i.totals.net,
      tax: i.totals.tax,
      total: total,
    ),
    createdAt: i.createdAt,
    updatedAt: i.updatedAt,
  );
}
