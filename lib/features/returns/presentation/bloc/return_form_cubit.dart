import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/returns/domain/entities/return_input.dart';
import 'package:inventrix/features/returns/domain/entities/returnable_invoice.dart';
import 'package:inventrix/features/returns/domain/services/return_planner.dart';
import 'package:inventrix/features/returns/domain/services/returnable_invoice_loader.dart';
import 'package:inventrix/features/returns/domain/usecases/post_return.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the return form.
final class ReturnFormState extends Equatable {
  /// Creates a state.
  const ReturnFormState({
    this.loadStatus = FormLoadStatus.loading,
    this.submitStatus = SubmitStatus.idle,
    this.kind = InvoiceKind.sales,
    this.query = '',
    this.choices = const [],
    this.invoice,
    this.quantities = const {},
    this.restock = const {},
    this.reason = '',
    this.notes = '',
    this.returnDate,
    this.refundText = '',
    this.refundMethodId,
    this.refundReference = '',
    this.methods = const [],
    this.plan,
    this.maxRefund,
    this.fieldErrors = const {},
    this.savedId,
    this.message,
  });

  /// Load status.
  final FormLoadStatus loadStatus;

  /// Submission status.
  final SubmitStatus submitStatus;

  /// Sales or purchase return.
  final InvoiceKind kind;

  /// Search text of the invoice chooser.
  final String query;

  /// Posted invoices to choose from.
  final List<InvoiceChoice> choices;

  /// The chosen invoice; `null` while choosing.
  final ReturnableInvoice? invoice;

  /// Quantity text per invoice line id.
  final Map<String, String> quantities;

  /// Restock choice per invoice line id (sales; default `true`).
  final Map<String, bool> restock;

  /// Reason text.
  final String reason;

  /// Notes text.
  final String notes;

  /// Return date.
  final DateTime? returnDate;

  /// Cash refund amount text.
  final String refundText;

  /// Cash refund method.
  final String? refundMethodId;

  /// Cash refund reference.
  final String refundReference;

  /// Active payment methods.
  final List<PaymentMethod> methods;

  /// Live plan of the lines entered so far.
  final ReturnPlan? plan;

  /// The most cash that can be handed back for the current plan.
  final Money? maxRefund;

  /// Field errors from the last attempt (`reason`, `refund`,
  /// `refundMethod`, `returnDate`, `line:<invoice line id>`).
  final Map<String, String> fieldErrors;

  /// Id of the saved return after success.
  final String? savedId;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message], [savedId] and [fieldErrors] reset unless
  /// provided.
  ReturnFormState copyWith({
    FormLoadStatus? loadStatus,
    SubmitStatus? submitStatus,
    InvoiceKind? kind,
    String? query,
    List<InvoiceChoice>? choices,
    ReturnableInvoice? invoice,
    bool clearInvoice = false,
    Map<String, String>? quantities,
    Map<String, bool>? restock,
    String? reason,
    String? notes,
    DateTime? returnDate,
    String? refundText,
    String? refundMethodId,
    String? refundReference,
    List<PaymentMethod>? methods,
    ReturnPlan? plan,
    Money? maxRefund,
    Map<String, String>? fieldErrors,
    String? savedId,
    String? message,
  }) => ReturnFormState(
    loadStatus: loadStatus ?? this.loadStatus,
    submitStatus: submitStatus ?? this.submitStatus,
    kind: kind ?? this.kind,
    query: query ?? this.query,
    choices: choices ?? this.choices,
    invoice: clearInvoice ? null : (invoice ?? this.invoice),
    quantities: quantities ?? this.quantities,
    restock: restock ?? this.restock,
    reason: reason ?? this.reason,
    notes: notes ?? this.notes,
    returnDate: returnDate ?? this.returnDate,
    refundText: refundText ?? this.refundText,
    refundMethodId: refundMethodId ?? this.refundMethodId,
    refundReference: refundReference ?? this.refundReference,
    methods: methods ?? this.methods,
    plan: clearInvoice ? null : (plan ?? this.plan),
    maxRefund: clearInvoice ? null : (maxRefund ?? this.maxRefund),
    fieldErrors: fieldErrors ?? const {},
    savedId: savedId,
    message: message,
  );

  @override
  List<Object?> get props => [
    loadStatus,
    submitStatus,
    kind,
    query,
    choices,
    invoice,
    quantities,
    restock,
    reason,
    notes,
    returnDate,
    refundText,
    refundMethodId,
    refundReference,
    methods,
    plan,
    maxRefund,
    fieldErrors,
    savedId,
    message,
  ];
}

/// Drives the return form: choose a posted invoice, enter quantities per
/// line, see the value of the return and the possible cash refund update
/// live (from the same [ReturnPlanner] that posts it), then post.
class ReturnFormCubit extends Cubit<ReturnFormState> {
  /// Creates the cubit.
  ReturnFormCubit({
    required ReturnableInvoiceLoader loader,
    required PaymentMethodRepository methods,
    required PostReturn postReturn,
    required IdGenerator ids,
  }) : _loader = loader,
       _methods = methods,
       _post = postReturn,
       _ids = ids,
       super(const ReturnFormState());

  final ReturnableInvoiceLoader _loader;
  final PaymentMethodRepository _methods;
  final PostReturn _post;
  final IdGenerator _ids;
  late String _key = _ids.newId();

  /// Opens the form. With [invoiceId] the invoice is preselected.
  Future<void> load({
    InvoiceKind kind = InvoiceKind.sales,
    String? invoiceId,
  }) async {
    final methods = await _methods.list();
    if (isClosed) {
      return;
    }
    final failure = methods.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          loadStatus: FormLoadStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final today = DateTime.now().toUtc();
    emit(
      ReturnFormState(
        loadStatus: FormLoadStatus.ready,
        kind: kind,
        methods: methods.valueOrNull!,
        returnDate: DateTime.utc(today.year, today.month, today.day),
      ),
    );
    if (invoiceId != null) {
      await selectInvoice(invoiceId);
    } else {
      await searchInvoices('');
    }
  }

  /// Switches between sales and purchase returns while choosing.
  Future<void> setKind(InvoiceKind kind) async {
    if (state.invoice != null || kind == state.kind) {
      return;
    }
    emit(state.copyWith(kind: kind, query: '', choices: const []));
    await searchInvoices('');
  }

  /// Searches posted invoices by number or party name.
  Future<void> searchInvoices(String query) async {
    emit(state.copyWith(query: query));
    final result = await _loader.choices(state.kind, query);
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    emit(
      failure != null
          ? state.copyWith(message: failure.userMessage)
          : state.copyWith(choices: result.valueOrNull),
    );
  }

  /// Chooses the invoice to return against.
  Future<void> selectInvoice(String invoiceId) async {
    final result = await _loader.load(state.kind, invoiceId);
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(message: failure.userMessage));
      return;
    }
    final invoice = result.valueOrNull!;
    emit(
      state.copyWith(
        invoice: invoice,
        quantities: const {},
        restock: const {},
        refundText: '',
      ),
    );
    _replan();
    if (!invoice.hasReturnable) {
      emit(
        state.copyWith(
          message: 'Everything on ${invoice.invoiceNumber} has already '
              'been returned.',
        ),
      );
    }
  }

  /// Goes back to choosing another invoice.
  Future<void> clearInvoice() async {
    emit(
      state.copyWith(
        clearInvoice: true,
        quantities: const {},
        restock: const {},
        refundText: '',
      ),
    );
    await searchInvoices(state.query);
  }

  /// Sets the quantity text of one invoice line.
  void setQuantity(String invoiceLineId, String text) {
    emit(
      state.copyWith(quantities: {...state.quantities, invoiceLineId: text}),
    );
    _replan();
  }

  /// Chooses whether a line goes back into stock (sales).
  void setRestock(String invoiceLineId, {required bool restock}) {
    emit(state.copyWith(restock: {...state.restock, invoiceLineId: restock}));
    _replan();
  }

  /// Fills every line with everything that can still be returned.
  void returnEverything() {
    final invoice = state.invoice;
    if (invoice == null) {
      return;
    }
    emit(
      state.copyWith(
        quantities: {
          for (final line in invoice.lines)
            if (line.returnable.isPositive)
              line.invoiceLineId: line.returnable.toDecimalString(),
        },
      ),
    );
    _replan();
  }

  /// Sets the reason.
  void setReason(String value) => emit(state.copyWith(reason: value));

  /// Sets the notes.
  void setNotes(String value) => emit(state.copyWith(notes: value));

  /// Sets the return date.
  void setDate(DateTime value) =>
      emit(state.copyWith(returnDate: DateTime.utc(value.year, value.month, value.day)));

  /// Sets the cash refund amount text.
  void setRefundText(String value) => emit(state.copyWith(refundText: value));

  /// Fills the refund with the most that can be handed back.
  void refundMaximum() {
    final max = state.maxRefund;
    if (max != null) {
      emit(state.copyWith(refundText: max.toPlainString()));
    }
  }

  /// Sets the refund method.
  void setRefundMethod(String? id) =>
      emit(state.copyWith(refundMethodId: id));

  /// Sets the refund reference.
  void setRefundReference(String value) =>
      emit(state.copyWith(refundReference: value));

  /// Posts the return.
  Future<void> submit() async {
    final invoice = state.invoice;
    if (invoice == null || state.submitStatus == SubmitStatus.submitting) {
      return;
    }
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final result = await _post(
      ReturnInput(
        kind: invoice.kind,
        invoiceId: invoice.invoiceId,
        returnDate: state.returnDate,
        reason: state.reason,
        notes: state.notes,
        lines: _lineInputs(invoice),
        refundAmount: state.refundText,
        refundMethodId: state.refundMethodId,
        refundReference: state.refundReference,
        idempotencyKey: _key,
      ),
    );
    if (isClosed) {
      return;
    }
    result.when(
      success: (document) => emit(
        state.copyWith(
          submitStatus: SubmitStatus.success,
          savedId: document.id,
        ),
      ),
      failure: (failure) {
        // A new attempt after a rejected one is a new attempt.
        _key = _ids.newId();
        emit(
          state.copyWith(
            submitStatus: failure is ValidationFailure
                ? SubmitStatus.validationError
                : SubmitStatus.failure,
            fieldErrors: failure is ValidationFailure
                ? failure.fieldErrors
                : const {},
            message: failure.userMessage,
          ),
        );
      },
    );
  }

  List<ReturnLineInput> _lineInputs(ReturnableInvoice invoice) => [
    for (final line in invoice.lines)
      ReturnLineInput(
        invoiceLineId: line.invoiceLineId,
        quantity: state.quantities[line.invoiceLineId] ?? '',
        restock: state.restock[line.invoiceLineId] ?? true,
      ),
  ];

  void _replan() {
    final invoice = state.invoice;
    if (invoice == null) {
      return;
    }
    final plan = ReturnPlanner.plan(invoice, _lineInputs(invoice));
    emit(
      state.copyWith(
        plan: plan,
        maxRefund: invoice.refundCapacity(plan.total),
      ),
    );
  }
}
