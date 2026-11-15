import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/utils/decimal_text.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_line.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_totals.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/services/purchase_line_builder.dart';
import 'package:inventrix/features/purchases/domain/usecases/save_purchase_draft.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the purchase form.
final class PurchaseFormState extends Equatable {
  /// Creates a state.
  const PurchaseFormState({
    this.loadStatus = FormLoadStatus.loading,
    this.submitStatus = SubmitStatus.idle,
    this.suppliers = const [],
    this.products = const [],
    this.units = const {},
    this.currency,
    this.purchaseId,
    this.supplierId,
    this.invoiceDate,
    this.dueDate,
    this.supplierReference = '',
    this.notes = '',
    this.lines = const [],
    this.previews = const [],
    this.totals,
    this.blockedReason,
    this.fieldErrors = const {},
    this.savedId,
    this.message,
  });

  /// Load status.
  final FormLoadStatus loadStatus;

  /// Submission status.
  final SubmitStatus submitStatus;

  /// Active suppliers to choose from.
  final List<Supplier> suppliers;

  /// Active products to choose from.
  final List<Product> products;

  /// Units by id.
  final Map<String, UnitOfMeasure> units;

  /// Active currency.
  final CurrencyConfig? currency;

  /// Id of the draft being edited, `null` when creating.
  final String? purchaseId;

  /// Chosen supplier.
  final String? supplierId;

  /// Invoice date.
  final DateTime? invoiceDate;

  /// Due date.
  final DateTime? dueDate;

  /// Supplier's own invoice number (loaded from an existing draft).
  final String supplierReference;

  /// Notes (loaded from an existing draft).
  final String notes;

  /// Line inputs, in order.
  final List<PurchaseLineInput> lines;

  /// Computed line per input (`null` where the input is invalid).
  final List<PurchaseLine?> previews;

  /// Totals of the valid lines.
  final PurchaseTotals? totals;

  /// Why the form cannot be used at all.
  final String? blockedReason;

  /// Field errors of the last submit (`lines.<i>.<field>` for lines).
  final Map<String, String> fieldErrors;

  /// Id of the saved draft after a successful submit.
  final String? savedId;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [fieldErrors] and [message] reset unless provided.
  PurchaseFormState copyWith({
    FormLoadStatus? loadStatus,
    SubmitStatus? submitStatus,
    List<Supplier>? suppliers,
    List<Product>? products,
    Map<String, UnitOfMeasure>? units,
    CurrencyConfig? currency,
    String? purchaseId,
    String? supplierId,
    DateTime? invoiceDate,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? supplierReference,
    String? notes,
    List<PurchaseLineInput>? lines,
    List<PurchaseLine?>? previews,
    PurchaseTotals? totals,
    String? blockedReason,
    Map<String, String>? fieldErrors,
    String? savedId,
    String? message,
  }) => PurchaseFormState(
    loadStatus: loadStatus ?? this.loadStatus,
    submitStatus: submitStatus ?? this.submitStatus,
    suppliers: suppliers ?? this.suppliers,
    products: products ?? this.products,
    units: units ?? this.units,
    currency: currency ?? this.currency,
    purchaseId: purchaseId ?? this.purchaseId,
    supplierId: supplierId ?? this.supplierId,
    invoiceDate: invoiceDate ?? this.invoiceDate,
    dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    supplierReference: supplierReference ?? this.supplierReference,
    notes: notes ?? this.notes,
    lines: lines ?? this.lines,
    previews: previews ?? this.previews,
    totals: totals ?? this.totals,
    blockedReason: blockedReason ?? this.blockedReason,
    fieldErrors: fieldErrors ?? const {},
    savedId: savedId ?? this.savedId,
    message: message,
  );

  @override
  List<Object?> get props => [
    loadStatus,
    submitStatus,
    suppliers,
    products,
    units,
    currency,
    purchaseId,
    supplierId,
    invoiceDate,
    dueDate,
    supplierReference,
    notes,
    lines,
    previews,
    totals,
    blockedReason,
    fieldErrors,
    savedId,
    message,
  ];
}

/// Drives the purchase form: header fields, an editable list of lines with
/// live totals, and saving the draft.
class PurchaseFormCubit extends Cubit<PurchaseFormState> {
  /// Creates the cubit.
  PurchaseFormCubit({
    required PurchaseRepository purchases,
    required SupplierRepository suppliers,
    required ProductRepository products,
    required UnitRepository units,
    required SettingsRepository settings,
    required PurchaseLineBuilder lineBuilder,
    required SavePurchaseDraft saveDraft,
  }) : _purchases = purchases,
       _suppliers = suppliers,
       _products = products,
       _units = units,
       _settings = settings,
       _builder = lineBuilder,
       _save = saveDraft,
       super(const PurchaseFormState());

  final PurchaseRepository _purchases;
  final SupplierRepository _suppliers;
  final ProductRepository _products;
  final UnitRepository _units;
  final SettingsRepository _settings;
  final PurchaseLineBuilder _builder;
  final SavePurchaseDraft _save;

  /// Loads reference data and, with [purchaseId], the draft to edit.
  Future<void> load({String? purchaseId}) async {
    emit(const PurchaseFormState());
    final suppliers = await _suppliers.search();
    final products = await _products.search(const ProductFilter());
    final units = await _units.search(includeArchived: true);
    final currency = await _settings.getCurrencyConfig();
    final existing = purchaseId == null
        ? null
        : await _purchases.getById(purchaseId);
    if (isClosed) {
      return;
    }
    final failure =
        suppliers.failureOrNull ??
        products.failureOrNull ??
        units.failureOrNull ??
        currency.failureOrNull ??
        existing?.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          loadStatus: failure is NotFoundFailure
              ? FormLoadStatus.notFound
              : FormLoadStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final today = DateTime.now().toUtc();
    var next = state.copyWith(
      loadStatus: FormLoadStatus.ready,
      suppliers: suppliers.valueOrNull,
      products: products.valueOrNull,
      units: {for (final u in units.valueOrNull!) u.id: u},
      currency: currency.valueOrNull,
      invoiceDate: DateTime.utc(today.year, today.month, today.day),
    );
    final invoice = existing?.valueOrNull;
    if (invoice != null) {
      next = next.copyWith(
        purchaseId: invoice.id,
        supplierId: invoice.supplierId,
        invoiceDate: invoice.invoiceDate,
        dueDate: invoice.dueDate,
        supplierReference: invoice.supplierReference ?? '',
        notes: invoice.notes ?? '',
        lines: [for (final l in invoice.lines) _inputOf(l)],
        blockedReason: invoice.isEditable
            ? null
            : 'Only drafts can be edited. This purchase is '
                  '${invoice.status.label.toLowerCase()}.',
      );
      // An existing draft may reference a supplier that is now archived.
      if (!next.suppliers.any((s) => s.id == invoice.supplierId)) {
        final supplier = await _suppliers.getById(invoice.supplierId);
        final found = supplier.valueOrNull;
        if (found != null) {
          next = next.copyWith(suppliers: [...next.suppliers, found]);
        }
      }
    }
    emit(next);
    await _recalculate();
  }

  /// Chooses the supplier.
  void setSupplier(String? id) => emit(state.copyWith(supplierId: id));

  /// Sets the invoice date.
  void setInvoiceDate(DateTime date) => emit(
    state.copyWith(invoiceDate: DateTime.utc(date.year, date.month, date.day)),
  );

  /// Sets or clears the due date.
  void setDueDate(DateTime? date) => emit(
    date == null
        ? state.copyWith(clearDueDate: true)
        : state.copyWith(
            dueDate: DateTime.utc(date.year, date.month, date.day),
          ),
  );

  /// Validates [input] and adds it (or replaces the line at [index]).
  ///
  /// Returns the field errors (`product`, `quantity`, `unitPrice`,
  /// `discount`); an empty map means the line was accepted.
  Future<Map<String, String>> saveLine(
    PurchaseLineInput input, {
    int? index,
  }) async {
    final currency = state.currency;
    if (currency == null) {
      return const {'product': 'The form is not ready.'};
    }
    final built = await _builder.build(
      input: input,
      lineNo: (index ?? state.lines.length) + 1,
      lineId: 'preview',
      currency: currency,
    );
    final failure = built.failureOrNull;
    if (failure != null) {
      return failure is ValidationFailure
          ? failure.fieldErrors
          : {'product': failure.userMessage};
    }
    final lines = [...state.lines];
    if (index == null) {
      lines.add(input);
    } else {
      lines[index] = input;
    }
    emit(state.copyWith(lines: lines));
    await _recalculate();
    return const {};
  }

  /// Removes the line at [index].
  Future<void> removeLine(int index) async {
    final lines = [...state.lines]..removeAt(index);
    emit(state.copyWith(lines: lines));
    await _recalculate();
  }

  /// Saves the draft. [supplierReference] and [notes] come from the text
  /// fields.
  Future<void> submit({
    String supplierReference = '',
    String notes = '',
  }) async {
    if (state.submitStatus == SubmitStatus.submitting ||
        state.blockedReason != null) {
      return;
    }
    emit(
      state.copyWith(
        submitStatus: SubmitStatus.submitting,
        supplierReference: supplierReference,
        notes: notes,
      ),
    );
    final result = await _save(
      PurchaseDraftInput(
        id: state.purchaseId,
        supplierId: state.supplierId ?? '',
        invoiceDate: state.invoiceDate,
        dueDate: state.dueDate,
        supplierReference: supplierReference,
        notes: notes,
        lines: state.lines,
      ),
    );
    if (isClosed) {
      return;
    }
    result.when(
      success: (PurchaseInvoice invoice) => emit(
        state.copyWith(
          submitStatus: SubmitStatus.success,
          purchaseId: invoice.id,
          savedId: invoice.id,
        ),
      ),
      failure: (failure) => emit(
        failure is ValidationFailure
            ? state.copyWith(
                submitStatus: SubmitStatus.validationError,
                fieldErrors: failure.fieldErrors,
                message: failure.fieldErrors.isEmpty ? failure.message : null,
              )
            : state.copyWith(
                submitStatus: SubmitStatus.failure,
                message: failure.userMessage,
              ),
      ),
    );
  }

  Future<void> _recalculate() async {
    final currency = state.currency;
    if (currency == null || isClosed) {
      return;
    }
    final previews = <PurchaseLine?>[];
    for (var i = 0; i < state.lines.length; i++) {
      final built = await _builder.build(
        input: state.lines[i],
        lineNo: i + 1,
        lineId: 'preview-$i',
        currency: currency,
      );
      previews.add(built.valueOrNull);
    }
    if (isClosed) {
      return;
    }
    emit(
      state.copyWith(
        previews: previews,
        totals: PurchaseTotals.fromLines(
          previews.whereType<PurchaseLine>(),
          zero: currency.zero(),
        ),
      ),
    );
  }

  PurchaseLineInput _inputOf(PurchaseLine line) => PurchaseLineInput(
    productId: line.productId,
    quantity: line.quantity.toDecimalString(),
    unitPrice: line.unitPrice.toPlainString(),
    discountKind: line.discount.kind,
    discountValue: switch (line.discount.kind) {
      DiscountKind.none => '',
      DiscountKind.percent => formatScaledDecimal(
        line.discount.basisPoints,
        scale: 2,
      ),
      DiscountKind.amount => line.discount.amount!.toPlainString(),
    },
  );
}
