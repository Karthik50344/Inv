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
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/sales_line_builder.dart';
import 'package:inventrix/features/sales/domain/services/sales_stock_check.dart';
import 'package:inventrix/features/sales/domain/usecases/save_sales_draft.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the sale form.
final class SalesFormState extends Equatable {
  /// Creates a state.
  const SalesFormState({
    this.loadStatus = FormLoadStatus.loading,
    this.submitStatus = SubmitStatus.idle,
    this.customers = const [],
    this.products = const [],
    this.units = const {},
    this.currency,
    this.saleId,
    this.customerId,
    this.invoiceDate,
    this.dueDate,
    this.customerReference = '',
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

  /// Active customers to choose from.
  final List<Customer> customers;

  /// Active products to choose from.
  final List<Product> products;

  /// Units by id.
  final Map<String, UnitOfMeasure> units;

  /// Active currency.
  final CurrencyConfig? currency;

  /// Id of the draft being edited, `null` when creating.
  final String? saleId;

  /// Chosen customer.
  final String? customerId;

  /// Invoice date.
  final DateTime? invoiceDate;

  /// Due date.
  final DateTime? dueDate;

  /// Customer's own invoice number (loaded from an existing draft).
  final String customerReference;

  /// Notes (loaded from an existing draft).
  final String notes;

  /// Line inputs, in order.
  final List<SalesLineInput> lines;

  /// Computed line per input (`null` where the input is invalid).
  final List<SalesLine?> previews;

  /// Totals of the valid lines.
  final SalesTotals? totals;

  /// Why the form cannot be used at all.
  final String? blockedReason;

  /// Field errors of the last submit (`lines.<i>.<field>` for lines).
  final Map<String, String> fieldErrors;

  /// Id of the saved draft after a successful submit.
  final String? savedId;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [fieldErrors] and [message] reset unless provided.
  SalesFormState copyWith({
    FormLoadStatus? loadStatus,
    SubmitStatus? submitStatus,
    List<Customer>? customers,
    List<Product>? products,
    Map<String, UnitOfMeasure>? units,
    CurrencyConfig? currency,
    String? saleId,
    String? customerId,
    bool clearCustomer = false,
    DateTime? invoiceDate,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? customerReference,
    String? notes,
    List<SalesLineInput>? lines,
    List<SalesLine?>? previews,
    SalesTotals? totals,
    String? blockedReason,
    Map<String, String>? fieldErrors,
    String? savedId,
    String? message,
  }) => SalesFormState(
    loadStatus: loadStatus ?? this.loadStatus,
    submitStatus: submitStatus ?? this.submitStatus,
    customers: customers ?? this.customers,
    products: products ?? this.products,
    units: units ?? this.units,
    currency: currency ?? this.currency,
    saleId: saleId ?? this.saleId,
    customerId: clearCustomer ? null : (customerId ?? this.customerId),
    invoiceDate: invoiceDate ?? this.invoiceDate,
    dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    customerReference: customerReference ?? this.customerReference,
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
    customers,
    products,
    units,
    currency,
    saleId,
    customerId,
    invoiceDate,
    dueDate,
    customerReference,
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

/// Drives the sale form: header fields, an editable list of lines with
/// live totals, and saving the draft.
class SalesFormCubit extends Cubit<SalesFormState> {
  /// Creates the cubit.
  SalesFormCubit({
    required SalesRepository sales,
    required CustomerRepository customers,
    required ProductRepository products,
    required UnitRepository units,
    required SettingsRepository settings,
    required SalesLineBuilder lineBuilder,
    required SalesStockCheck stockCheck,
    required SaveSalesDraft saveDraft,
  }) : _sales = sales,
       _customers = customers,
       _products = products,
       _units = units,
       _settings = settings,
       _builder = lineBuilder,
       _stockCheck = stockCheck,
       _save = saveDraft,
       super(const SalesFormState());

  final SalesRepository _sales;
  final CustomerRepository _customers;
  final ProductRepository _products;
  final UnitRepository _units;
  final SettingsRepository _settings;
  final SalesLineBuilder _builder;
  final SalesStockCheck _stockCheck;
  final SaveSalesDraft _save;

  /// Loads reference data and, with [saleId], the draft to edit.
  Future<void> load({String? saleId}) async {
    emit(const SalesFormState());
    final customers = await _customers.search();
    final products = await _products.search(const ProductFilter());
    final units = await _units.search(includeArchived: true);
    final currency = await _settings.getCurrencyConfig();
    final existing = saleId == null ? null : await _sales.getById(saleId);
    if (isClosed) {
      return;
    }
    final failure =
        customers.failureOrNull ??
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
      customers: customers.valueOrNull,
      products: products.valueOrNull,
      units: {for (final u in units.valueOrNull!) u.id: u},
      currency: currency.valueOrNull,
      invoiceDate: DateTime.utc(today.year, today.month, today.day),
    );
    final invoice = existing?.valueOrNull;
    if (invoice != null) {
      next = next.copyWith(
        saleId: invoice.id,
        customerId: invoice.customerId,
        invoiceDate: invoice.invoiceDate,
        dueDate: invoice.dueDate,
        customerReference: invoice.customerReference ?? '',
        notes: invoice.notes ?? '',
        lines: [for (final l in invoice.lines) _inputOf(l)],
        blockedReason: invoice.isEditable
            ? null
            : 'Only drafts can be edited. This sale is '
                  '${invoice.status.label.toLowerCase()}.',
      );
      // An existing draft may reference a customer that is now archived.
      final savedCustomerId = invoice.customerId;
      if (savedCustomerId != null &&
          !next.customers.any((s) => s.id == savedCustomerId)) {
        final customer = await _customers.getById(savedCustomerId);
        final found = customer.valueOrNull;
        if (found != null) {
          next = next.copyWith(customers: [...next.customers, found]);
        }
      }
    }
    emit(next);
    await _recalculate();
  }

  /// Chooses the customer; `null` records a walk-in sale.
  void setCustomer(String? id) => emit(
    id == null
        ? state.copyWith(clearCustomer: true)
        : state.copyWith(customerId: id),
  );

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
    SalesLineInput input, {
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
    // Stock must cover this line together with the other lines of the
    // same product.
    final candidate = <SalesLine>[];
    var newPosition = 0;
    for (var i = 0; i < state.lines.length; i++) {
      if (i == index) {
        newPosition = candidate.length;
        candidate.add(built.valueOrNull!);
      } else if (state.previews.length > i && state.previews[i] != null) {
        candidate.add(state.previews[i]!);
      }
    }
    if (index == null) {
      newPosition = candidate.length;
      candidate.add(built.valueOrNull!);
    }
    final shortages = await _stockCheck.findShortages(candidate);
    final shortage = shortages.valueOrNull?[newPosition];
    if (shortage != null) {
      return {'quantity': shortage};
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

  /// Saves the draft. [customerReference] and [notes] come from the text
  /// fields.
  Future<void> submit({
    String customerReference = '',
    String notes = '',
  }) async {
    if (state.submitStatus == SubmitStatus.submitting ||
        state.blockedReason != null) {
      return;
    }
    emit(
      state.copyWith(
        submitStatus: SubmitStatus.submitting,
        customerReference: customerReference,
        notes: notes,
      ),
    );
    final result = await _save(
      SalesDraftInput(
        id: state.saleId,
        customerId: state.customerId,
        invoiceDate: state.invoiceDate,
        dueDate: state.dueDate,
        customerReference: customerReference,
        notes: notes,
        lines: state.lines,
      ),
    );
    if (isClosed) {
      return;
    }
    result.when(
      success: (SalesInvoice invoice) => emit(
        state.copyWith(
          submitStatus: SubmitStatus.success,
          saleId: invoice.id,
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
    final previews = <SalesLine?>[];
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
        totals: SalesTotals.fromLines(
          previews.whereType<SalesLine>(),
          zero: currency.zero(),
        ),
      ),
    );
  }

  SalesLineInput _inputOf(SalesLine line) => SalesLineInput(
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
