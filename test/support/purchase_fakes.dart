import 'payment_guard_fake.dart';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_filter.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_summary.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_totals.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/services/purchase_line_builder.dart';
import 'package:inventrix/features/purchases/domain/usecases/get_supplier_payable.dart';
import 'package:inventrix/features/purchases/domain/usecases/post_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/save_purchase_draft.dart';
import 'package:inventrix/features/purchases/domain/usecases/transition_purchase.dart';
import 'package:inventrix/features/purchases/domain/usecases/void_purchase.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import 'fakes.dart';
import 'return_fakes.dart' show NoReturns;
import 'inventory_fakes.dart';
import 'inventory_fixture.dart';

/// In-memory purchase repository that emulates the guarded SQL updates.
class FakePurchaseRepository implements PurchaseRepository, Rollbackable {
  Map<String, PurchaseInvoice> items = {};
  Failure? saveFailure;

  @override
  Object snapshot() => Map<String, PurchaseInvoice>.of(items);

  @override
  void restore(Object snapshot) => items = Map<String, PurchaseInvoice>.of(
    snapshot as Map<String, PurchaseInvoice>,
  );

  @override
  Future<Result<List<PurchaseSummary>>> search(PurchaseFilter filter) async {
    final q = filter.query.toLowerCase();
    final list = items.values.where((i) {
      if (filter.status != null && i.status != filter.status) return false;
      if (filter.supplierId != null && i.supplierId != filter.supplierId) {
        return false;
      }
      return q.isEmpty ||
          (i.number?.toLowerCase().contains(q) ?? false) ||
          i.supplierName.toLowerCase().contains(q) ||
          (i.supplierReference?.toLowerCase().contains(q) ?? false);
    }).toList()..sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));
    return Result.success([
      for (final i in list)
        PurchaseSummary(
          id: i.id,
          number: i.number,
          supplierId: i.supplierId,
          supplierName: i.supplierName,
          status: i.status,
          invoiceDate: i.invoiceDate,
          dueDate: i.dueDate,
          supplierReference: i.supplierReference,
          total: i.totals.total,
          lineCount: i.lines.length,
        ),
    ]);
  }

  @override
  Future<Result<PurchaseInvoice>> getById(String id) async => items[id] == null
      ? const Result.failure(NotFoundFailure('Purchase not found.'))
      : Result.success(items[id]!);

  @override
  Future<Result<void>> saveDraft(PurchaseInvoice invoice) async {
    if (saveFailure != null) return Result.failure(saveFailure!);
    final existing = items[invoice.id];
    if (existing != null && existing.status != DocumentStatus.draft) {
      return const Result.failure(
        ValidationFailure('Only draft purchases can be edited.'),
      );
    }
    items[invoice.id] = invoice;
    return const Result.success(null);
  }

  PurchaseInvoice _copy(
    PurchaseInvoice i, {
    DocumentStatus? status,
    String? number,
    DateTime? at,
    DateTime? postedAt,
    DateTime? cancelledAt,
    DateTime? voidedAt,
    String? voidReason,
  }) => PurchaseInvoice(
    id: i.id,
    number: number ?? i.number,
    supplierId: i.supplierId,
    supplierName: i.supplierName,
    status: status ?? i.status,
    invoiceDate: i.invoiceDate,
    dueDate: i.dueDate,
    supplierReference: i.supplierReference,
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

  Result<PurchaseInvoice> _guard(String id, Set<DocumentStatus> from) {
    final i = items[id];
    if (i == null)
      return const Result.failure(NotFoundFailure('Purchase not found.'));
    if (!from.contains(i.status)) {
      return const Result.failure(
        ValidationFailure('This purchase was changed in the meantime.'),
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
  Future<Result<Money>> postedTotalForSupplier(String supplierId) async {
    final posted = items.values.where(
      (i) => i.supplierId == supplierId && i.status == DocumentStatus.posted,
    );
    var sum = Money.zero(currencyCode: 'INR', decimalPlaces: 2);
    for (final i in posted) {
      sum += i.totals.total;
    }
    return Result.success(sum);
  }
}

/// Counter-based sequence that can emulate a rollback.
class FakeDocumentSequenceRepository
    implements DocumentSequenceRepository, Rollbackable {
  Map<String, int> counters = {};

  @override
  Object snapshot() => Map<String, int>.of(counters);

  @override
  void restore(Object snapshot) =>
      counters = Map<String, int>.of(snapshot as Map<String, int>);

  @override
  Future<Result<int>> next(String key) async {
    counters[key] = (counters[key] ?? 0) + 1;
    return Result.success(counters[key]!);
  }
}

/// Wires the purchase use cases on top of the inventory fixture.
class PurchaseFixture extends InventoryFixture {
  PurchaseFixture() {
    purchases = FakePurchaseRepository();
    sequences = FakeDocumentSequenceRepository();
    suppliers = FakeSupplierRepository();
    purchaseTx = FakeTransactionRunner([
      inventory,
      audit,
      purchases,
      sequences,
    ]);
    lineBuilder = PurchaseLineBuilder(
      products: products,
      units: units,
      taxRates: taxRates,
    );
    saveDraft = SavePurchaseDraft(
      purchases: purchases,
      suppliers: suppliers,
      lineBuilder: lineBuilder,
      settings: settings,
      audit: audit,
      transactions: purchaseTx,
      ids: ids,
      clock: clock,
    );
    transition = TransitionPurchase(
      purchases: purchases,
      settings: settings,
      audit: audit,
      transactions: purchaseTx,
      ids: ids,
      clock: clock,
    );
    post = PostPurchase(
      purchases: purchases,
      suppliers: suppliers,
      products: products,
      inventory: inventory,
      sequences: sequences,
      settings: settings,
      audit: audit,
      transactions: purchaseTx,
      ids: ids,
      clock: clock,
    );
    voidPurchase = VoidPurchase(
      purchases: purchases,
      inventory: inventory,
      audit: audit,
      payments: guard,
      returns: const NoReturns(),
      transactions: purchaseTx,
      ids: ids,
      clock: clock,
    );
    payable = GetSupplierPayable(purchases: purchases, suppliers: suppliers);
    addSupplier();
  }

  final SwitchableGuard guard = SwitchableGuard();
  late final FakePurchaseRepository purchases;
  late final FakeDocumentSequenceRepository sequences;
  late final FakeSupplierRepository suppliers;
  late final FakeTransactionRunner purchaseTx;
  late final PurchaseLineBuilder lineBuilder;
  late final SavePurchaseDraft saveDraft;
  late final TransitionPurchase transition;
  late final PostPurchase post;
  late final VoidPurchase voidPurchase;
  late final GetSupplierPayable payable;

  Supplier addSupplier({String id = 's1', String name = 'Acme Supplies'}) {
    final now = clock.now();
    final supplier = Supplier(
      id: id,
      name: name,
      openingBalance: Money.zero(currencyCode: 'INR', decimalPlaces: 2),
      createdAt: now,
      updatedAt: now,
    );
    suppliers.items[id] = supplier;
    return supplier;
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
    String purchase = '100',
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
            purchasePrice: purchase,
            taxRateId: taxRateId,
            priceIncludesTax: inclusive,
          ),
        );
    return result.valueOrNull!;
  }

  /// Saves a one-supplier draft and returns it (fails the test run if
  /// invalid).
  Future<PurchaseInvoice> draft(
    List<PurchaseLineInput> lines, {
    String supplierId = 's1',
    String? id,
  }) async {
    final result = await saveDraft(
      PurchaseDraftInput(
        id: id,
        supplierId: supplierId,
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
abstract final class PurchaseInvoiceTamper {
  static PurchaseInvoice withTotal(PurchaseInvoice i, Money total) =>
      PurchaseInvoice(
        id: i.id,
        number: i.number,
        supplierId: i.supplierId,
        supplierName: i.supplierName,
        status: i.status,
        invoiceDate: i.invoiceDate,
        dueDate: i.dueDate,
        supplierReference: i.supplierReference,
        notes: i.notes,
        lines: i.lines,
        totals: PurchaseTotals(
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
