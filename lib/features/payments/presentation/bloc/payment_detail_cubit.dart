import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/entities/payment_position.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/usecases/allocate_payment_credit.dart';
import 'package:inventrix/features/payments/domain/usecases/get_open_invoices.dart';
import 'package:inventrix/features/payments/domain/usecases/record_refund.dart';
import 'package:inventrix/features/payments/domain/usecases/reverse_payment.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// State of the payment detail screen.
final class PaymentDetailState extends Equatable {
  /// Creates a state.
  const PaymentDetailState({
    this.status = DetailStatus.loading,
    this.payment,
    this.position,
    this.refunds = const [],
    this.openInvoices = const [],
    this.currency,
    this.busy = false,
    this.message,
  });

  /// Loading status.
  final DetailStatus status;

  /// The payment.
  final Payment? payment;

  /// Unspent amount, for payments (not refunds).
  final PaymentPosition? position;

  /// Active refunds taken from this payment.
  final List<Payment> refunds;

  /// Invoices the credit could be applied to.
  final List<OpenInvoice> openInvoices;

  /// Currency for parsing typed amounts.
  final CurrencyConfig? currency;

  /// Whether an action is running.
  final bool busy;

  /// Message for the user.
  final String? message;

  /// Whether the payment can be reversed.
  bool get canReverse => payment != null && payment!.isActive;

  /// Whether part of the payment can be refunded.
  bool get canRefund =>
      payment != null &&
      payment!.isActive &&
      !payment!.isRefund &&
      (position?.refundable.isPositive ?? false);

  /// Whether unallocated credit can be applied to open invoices.
  bool get canAllocate =>
      payment != null &&
      payment!.isActive &&
      !payment!.isRefund &&
      (position?.credit.isPositive ?? false) &&
      openInvoices.isNotEmpty;

  /// A copy with changes.
  PaymentDetailState copyWith({
    DetailStatus? status,
    Payment? payment,
    PaymentPosition? position,
    List<Payment>? refunds,
    List<OpenInvoice>? openInvoices,
    CurrencyConfig? currency,
    bool? busy,
    String? message,
  }) => PaymentDetailState(
    status: status ?? this.status,
    payment: payment ?? this.payment,
    position: position ?? this.position,
    refunds: refunds ?? this.refunds,
    openInvoices: openInvoices ?? this.openInvoices,
    currency: currency ?? this.currency,
    busy: busy ?? this.busy,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    payment,
    position,
    refunds,
    openInvoices,
    currency,
    busy,
    message,
  ];
}

/// Shows one payment and runs reverse / refund / allocate-credit on it.
class PaymentDetailCubit extends Cubit<PaymentDetailState> {
  /// Creates the cubit.
  PaymentDetailCubit({
    required PaymentRepository payments,
    required GetOpenInvoices openInvoices,
    required ReversePayment reversePayment,
    required RecordRefund recordRefund,
    required AllocatePaymentCredit allocateCredit,
    required SettingsRepository settings,
    required IdGenerator ids,
    required Clock clock,
  }) : _payments = payments,
       _open = openInvoices,
       _reverse = reversePayment,
       _refund = recordRefund,
       _allocate = allocateCredit,
       _settings = settings,
       _ids = ids,
       _clock = clock,
       super(const PaymentDetailState());

  final PaymentRepository _payments;
  final GetOpenInvoices _open;
  final ReversePayment _reverse;
  final RecordRefund _refund;
  final AllocatePaymentCredit _allocate;
  final SettingsRepository _settings;
  final IdGenerator _ids;
  final Clock _clock;
  String? _id;

  /// Loads (or reloads) the payment.
  Future<void> load(String id, {String? message}) async {
    _id = id;
    final result = await _payments.getById(id);
    final currency = (await _settings.getCurrencyConfig()).valueOrNull;
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(
        PaymentDetailState(
          status: failure is NotFoundFailure
              ? DetailStatus.notFound
              : DetailStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final payment = result.valueOrNull!;
    var refunds = <Payment>[];
    PaymentPosition? position;
    var invoices = <OpenInvoice>[];
    if (!payment.isRefund) {
      refunds =
          (await _payments.activeRefundsOf(id)).valueOrNull ?? <Payment>[];
      position = PaymentPosition.of(payment, refunds);
      if (payment.isActive && position.credit.isPositive) {
        invoices =
            (await _open.forParty(
              payment.partyType,
              payment.partyId,
            )).valueOrNull ??
            <OpenInvoice>[];
      }
    }
    if (isClosed) {
      return;
    }
    emit(
      PaymentDetailState(
        status: DetailStatus.loaded,
        payment: payment,
        position: position,
        refunds: refunds,
        openInvoices: invoices,
        currency: currency,
        message: message,
      ),
    );
  }

  /// Reverses the payment; returns whether it worked.
  Future<bool> reverse(String reason) => _run(
    () async => (await _reverse(_id!, reason: reason)).failureOrNull,
    done: 'Payment reversed.',
  );

  /// Refunds [amount] (typed); [reductions] maps invoice ids to the typed
  /// amount to take back off each invoice.
  Future<bool> refund({
    required String amount,
    required String reason,
    Map<String, String> reductions = const {},
  }) {
    final currency = state.currency;
    final money = currency?.parse(amount);
    if (currency == null || money == null || !money.isPositive) {
      emit(state.copyWith(message: 'Enter an amount greater than zero.'));
      return Future.value(false);
    }
    final requests = _requests(currency, reductions);
    if (requests == null) {
      return Future.value(false);
    }
    return _run(
      () async => (await _refund(
        RecordRefundInput(
          paymentId: _id!,
          amount: money,
          refundDate: _today(),
          reason: reason,
          idempotencyKey: _ids.newId(),
          reductions: requests,
        ),
      )).failureOrNull,
      done: 'Refund recorded.',
    );
  }

  /// Applies unallocated credit to invoices; [amounts] maps invoice ids to
  /// typed amounts.
  Future<bool> allocateCredit(Map<String, String> amounts) {
    final currency = state.currency;
    if (currency == null) {
      return Future.value(false);
    }
    final requests = _requests(currency, amounts);
    if (requests == null) {
      return Future.value(false);
    }
    return _run(
      () async => (await _allocate(_id!, requests)).failureOrNull,
      done: 'Credit applied.',
    );
  }

  List<AllocationRequest>? _requests(
    CurrencyConfig currency,
    Map<String, String> typed,
  ) {
    final requests = <AllocationRequest>[];
    for (final entry in typed.entries) {
      if (entry.value.trim().isEmpty) {
        continue;
      }
      final value = currency.parse(entry.value);
      if (value == null || value.isNegative) {
        emit(state.copyWith(message: 'Enter valid amounts.'));
        return null;
      }
      if (value.isPositive) {
        requests.add(AllocationRequest(invoiceId: entry.key, amount: value));
      }
    }
    return requests;
  }

  DateTime _today() {
    final now = _clock.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day);
  }

  Future<bool> _run(
    Future<Failure?> Function() action, {
    required String done,
  }) async {
    final id = _id;
    if (id == null || state.busy) {
      return false;
    }
    emit(state.copyWith(busy: true));
    final failure = await action();
    if (isClosed) {
      return failure == null;
    }
    await load(id, message: failure?.userMessage ?? done);
    return failure == null;
  }
}
