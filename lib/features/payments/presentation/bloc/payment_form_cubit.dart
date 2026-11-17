import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/payments/domain/services/allocation_planner.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/payments/domain/usecases/get_open_invoices.dart';
import 'package:inventrix/features/payments/domain/usecases/record_payment.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Where the payment form is in its life.
enum PaymentFormStatus {
  /// Loading parties, methods and invoices.
  loading,

  /// Ready for input.
  ready,

  /// Being saved.
  saving,

  /// Saved; `saved` is set.
  saved,

  /// Could not load.
  failure,
}

/// State of the payment form.
final class PaymentFormState extends Equatable {
  /// Creates a state.
  const PaymentFormState({
    required this.partyType,
    required this.date,
    this.status = PaymentFormStatus.loading,
    this.currency,
    this.parties = const [],
    this.partyId,
    this.partyLocked = false,
    this.methods = const [],
    this.methodId,
    this.amount = '',
    this.reference = '',
    this.notes = '',
    this.invoices = const [],
    this.allocations = const {},
    this.autoAllocate = true,
    this.fieldErrors = const {},
    this.message,
    this.saved,
  });

  /// Customer receipt or supplier payment.
  final PartyType partyType;

  /// Payment date.
  final DateTime date;

  /// Form status.
  final PaymentFormStatus status;

  /// Currency used for amounts.
  final CurrencyConfig? currency;

  /// Selectable parties.
  final List<Party> parties;

  /// The chosen party.
  final String? partyId;

  /// Whether the party was fixed by the entry point and cannot change.
  final bool partyLocked;

  /// Active payment methods.
  final List<PaymentMethod> methods;

  /// The chosen method.
  final String? methodId;

  /// Amount as typed.
  final String amount;

  /// Reference as typed.
  final String reference;

  /// Notes as typed.
  final String notes;

  /// Invoices of the party with something outstanding, oldest first.
  final List<OpenInvoice> invoices;

  /// Allocation amounts as typed, by invoice id.
  final Map<String, String> allocations;

  /// Whether allocations follow the amount (oldest invoices first).
  final bool autoAllocate;

  /// Validation messages by field.
  final Map<String, String> fieldErrors;

  /// Message for the user.
  final String? message;

  /// The recorded payment once saved.
  final Payment? saved;

  /// The parsed amount, or `null` if empty or invalid.
  Money? get amountMoney => currency?.parse(amount);

  /// Sum of the allocation amounts that parse.
  Money? get allocatedTotal {
    final c = currency;
    if (c == null) {
      return null;
    }
    var total = c.zero();
    for (final text in allocations.values) {
      final value = c.parse(text);
      if (value != null) {
        total += value;
      }
    }
    return total;
  }

  /// What would stay unallocated (credit); negative when over-allocated.
  Money? get unallocated {
    final amount = amountMoney;
    final allocated = allocatedTotal;
    return (amount == null || allocated == null) ? null : amount - allocated;
  }

  /// A copy with changes.
  PaymentFormState copyWith({
    PaymentFormStatus? status,
    CurrencyConfig? currency,
    List<Party>? parties,
    String? partyId,
    bool? partyLocked,
    List<PaymentMethod>? methods,
    String? methodId,
    DateTime? date,
    String? amount,
    String? reference,
    String? notes,
    List<OpenInvoice>? invoices,
    Map<String, String>? allocations,
    bool? autoAllocate,
    Map<String, String>? fieldErrors,
    String? message,
    Payment? saved,
  }) => PaymentFormState(
    partyType: partyType,
    date: date ?? this.date,
    status: status ?? this.status,
    currency: currency ?? this.currency,
    parties: parties ?? this.parties,
    partyId: partyId ?? this.partyId,
    partyLocked: partyLocked ?? this.partyLocked,
    methods: methods ?? this.methods,
    methodId: methodId ?? this.methodId,
    amount: amount ?? this.amount,
    reference: reference ?? this.reference,
    notes: notes ?? this.notes,
    invoices: invoices ?? this.invoices,
    allocations: allocations ?? this.allocations,
    autoAllocate: autoAllocate ?? this.autoAllocate,
    fieldErrors: fieldErrors ?? const {},
    message: message,
    saved: saved ?? this.saved,
  );

  @override
  List<Object?> get props => [
    partyType,
    date,
    status,
    currency,
    parties,
    partyId,
    partyLocked,
    methods,
    methodId,
    amount,
    reference,
    notes,
    invoices,
    allocations,
    autoAllocate,
    fieldErrors,
    message,
    saved,
  ];
}

/// Drives the "receive payment" / "record payment" form.
class PaymentFormCubit extends Cubit<PaymentFormState> {
  /// Creates the cubit.
  PaymentFormCubit({
    required PartyDirectory parties,
    required PaymentMethodRepository methods,
    required GetOpenInvoices openInvoices,
    required RecordPayment recordPayment,
    required SettingsRepository settings,
    required IdGenerator ids,
    required Clock clock,
    PreferencesRepository? preferences,
  }) : _preferences = preferences,
       _parties = parties,
       _methods = methods,
       _open = openInvoices,
       _record = recordPayment,
       _settings = settings,
       _ids = ids,
       _clock = clock,
       super(
         PaymentFormState(partyType: PartyType.customer, date: _today(clock)),
       );

  final PreferencesRepository? _preferences;
  final PartyDirectory _parties;
  final PaymentMethodRepository _methods;
  final GetOpenInvoices _open;
  final RecordPayment _record;
  final SettingsRepository _settings;
  final IdGenerator _ids;
  final Clock _clock;

  // One key per form: submitting twice can never record two payments.
  late final String _key = _ids.newId();

  static DateTime _today(Clock clock) {
    final now = clock.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  /// Loads the form. [partyId] fixes the party; [invoiceId] pre-fills the
  /// amount and allocation for that invoice.
  Future<void> load({
    required PartyType type,
    String? partyId,
    String? invoiceId,
  }) async {
    emit(PaymentFormState(partyType: type, date: _today(_clock)));
    final currencyResult = await _settings.getCurrencyConfig();
    final methodsResult = await _methods.list();
    final partiesResult = await _parties.all(type);
    final defaultMethodId =
        (await _preferences?.load())?.valueOrNull?.defaultPaymentMethodId;
    final failure =
        currencyResult.failureOrNull ??
        methodsResult.failureOrNull ??
        partiesResult.failureOrNull;
    if (isClosed) {
      return;
    }
    if (failure != null) {
      emit(
        PaymentFormState(
          partyType: type,
          date: _today(_clock),
          status: PaymentFormStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final methods = methodsResult.valueOrNull!;
    final parties = [
      for (final p in partiesResult.valueOrNull!)
        if (!p.isArchived || p.id == partyId) p,
    ];
    emit(
      PaymentFormState(
        partyType: type,
        date: _today(_clock),
        status: PaymentFormStatus.ready,
        currency: currencyResult.valueOrNull,
        parties: parties,
        partyId: partyId,
        partyLocked: partyId != null,
        methods: methods,
        methodId: methods.isEmpty
            ? null
            : (methods.any((m) => m.id == defaultMethodId)
                  ? defaultMethodId
                  : methods.first.id),
      ),
    );
    if (partyId != null) {
      await _loadInvoices(partyId, preferInvoice: invoiceId);
    }
  }

  /// Chooses the party and loads its open invoices.
  Future<void> selectParty(String partyId) async {
    if (state.partyLocked || partyId == state.partyId) {
      return;
    }
    emit(
      state.copyWith(
        partyId: partyId,
        invoices: const [],
        allocations: const {},
      ),
    );
    await _loadInvoices(partyId);
  }

  /// Chooses the payment method.
  void selectMethod(String id) => emit(state.copyWith(methodId: id));

  /// Sets the payment date.
  void setDate(DateTime date) =>
      emit(state.copyWith(date: DateTime.utc(date.year, date.month, date.day)));

  /// Sets the reference text.
  void setReference(String value) =>
      emit(_keepErrors(state.copyWith(reference: value)));

  /// Sets the notes text.
  void setNotes(String value) =>
      emit(_keepErrors(state.copyWith(notes: value)));

  /// Sets the amount; with auto-allocation on, spreads it over the oldest
  /// invoices.
  void setAmount(String value) {
    var next = state.copyWith(amount: value);
    if (state.autoAllocate) {
      next = next.copyWith(allocations: _autoAllocations(next));
    }
    emit(next);
  }

  /// Turns auto-allocation on or off.
  void setAutoAllocate({required bool value}) {
    var next = state.copyWith(autoAllocate: value);
    if (value) {
      next = next.copyWith(allocations: _autoAllocations(next));
    }
    emit(next);
  }

  /// Sets the amount applied to one invoice by hand (turns auto-allocation
  /// off).
  void setAllocation(String invoiceId, String value) {
    final map = Map<String, String>.of(state.allocations);
    if (value.trim().isEmpty) {
      map.remove(invoiceId);
    } else {
      map[invoiceId] = value;
    }
    emit(state.copyWith(autoAllocate: false, allocations: map));
  }

  /// Validates and records the payment.
  Future<void> submit() async {
    if (state.status == PaymentFormStatus.saving ||
        state.status == PaymentFormStatus.saved) {
      return;
    }
    final currency = state.currency;
    final partyId = state.partyId;
    final methodId = state.methodId;
    final errors = <String, String>{};
    if (partyId == null) {
      errors['party'] = 'Choose a ${state.partyType.label.toLowerCase()}.';
    }
    if (methodId == null) {
      errors['method'] = 'Choose a payment method.';
    }
    final amount = state.amountMoney;
    if (amount == null || !amount.isPositive) {
      errors['amount'] = 'Enter an amount greater than zero.';
    }
    final requests = <AllocationRequest>[];
    if (currency != null) {
      for (final entry in state.allocations.entries) {
        final value = currency.parse(entry.value);
        if (value == null || value.isNegative) {
          errors['allocation_${entry.key}'] = 'Enter a valid amount.';
        } else if (value.isPositive) {
          requests.add(AllocationRequest(invoiceId: entry.key, amount: value));
        }
      }
    }
    if (errors.isNotEmpty || currency == null) {
      emit(state.copyWith(fieldErrors: errors, message: 'Check the form.'));
      return;
    }
    emit(state.copyWith(status: PaymentFormStatus.saving));
    final result = await _record(
      RecordPaymentInput(
        partyType: state.partyType,
        partyId: partyId!,
        methodId: methodId!,
        amount: amount!,
        paymentDate: state.date,
        idempotencyKey: _key,
        allocations: requests,
        reference: state.reference,
        notes: state.notes,
      ),
    );
    if (isClosed) {
      return;
    }
    result.when(
      success: (payment) =>
          emit(state.copyWith(status: PaymentFormStatus.saved, saved: payment)),
      failure: (failure) => emit(
        state.copyWith(
          status: PaymentFormStatus.ready,
          fieldErrors: failure is ValidationFailure ? failure.fieldErrors : {},
          message: failure.userMessage,
        ),
      ),
    );
  }

  Future<void> _loadInvoices(String partyId, {String? preferInvoice}) async {
    final result = await _open.forParty(state.partyType, partyId);
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(message: failure.userMessage));
      return;
    }
    final invoices = result.valueOrNull!;
    var next = state.copyWith(invoices: invoices);
    if (preferInvoice != null) {
      final match = invoices.where((i) => i.id == preferInvoice).firstOrNull;
      if (match != null) {
        next = next.copyWith(
          amount: match.outstanding.toPlainString(),
          allocations: {preferInvoice: match.outstanding.toPlainString()},
        );
      }
    }
    emit(next);
  }

  Map<String, String> _autoAllocations(PaymentFormState from) {
    final amount = from.amountMoney;
    if (amount == null || !amount.isPositive) {
      return const {};
    }
    return {
      for (final r in AllocationPlanner.oldestFirst(from.invoices, amount))
        r.invoiceId: r.amount.toPlainString(),
    };
  }

  PaymentFormState _keepErrors(PaymentFormState next) =>
      next.copyWith(fieldErrors: state.fieldErrors);
}
