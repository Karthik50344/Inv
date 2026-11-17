import 'package:equatable/equatable.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_allocation.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';
import 'package:inventrix/features/payments/domain/entities/payment_reversal.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Audit names of payments and refunds. Their numbers come from
/// `DocumentKind.payment` and `DocumentKind.refund`.
abstract final class PaymentNumbering {
  /// Audit entity type.
  static const String auditType = 'payment';
}

/// A payment received from a customer or made to a supplier, or a refund
/// of one. Immutable once recorded: it is cancelled by a [PaymentReversal],
/// never edited or deleted.
final class Payment extends Equatable {
  /// Creates a payment.
  const Payment({
    required this.id,
    required this.number,
    required this.kind,
    required this.partyType,
    required this.partyId,
    required this.partyName,
    required this.methodId,
    required this.methodName,
    required this.paymentDate,
    required this.amount,
    required this.idempotencyKey,
    required this.createdAt,
    this.reference,
    this.notes,
    this.refundOfPaymentId,
    this.allocations = const [],
    this.reversal,
  });

  /// Unique id.
  final String id;

  /// Document number (`PAY-000001` / `RFD-000001`).
  final String number;

  /// Payment or refund.
  final PaymentKind kind;

  /// Customer or supplier.
  final PartyType partyType;

  /// Id of the customer or supplier.
  final String partyId;

  /// Party name at the time of recording.
  final String partyName;

  /// The payment method used.
  final String methodId;

  /// Method name at the time of recording.
  final String methodName;

  /// The date of the payment (UTC).
  final DateTime paymentDate;

  /// Positive amount of money that changed hands.
  final Money amount;

  /// Key that makes recording safe to repeat.
  final String idempotencyKey;

  /// When the record was created (UTC).
  final DateTime createdAt;

  /// Cheque number, transaction id, ...
  final String? reference;

  /// Free-form notes (the reason for a refund).
  final String? notes;

  /// For a refund: the payment it gives money back from.
  final String? refundOfPaymentId;

  /// Invoice allocations (negative amounts for a refund).
  final List<PaymentAllocation> allocations;

  /// Set when the payment was reversed.
  final PaymentReversal? reversal;

  /// Whether the payment was reversed.
  bool get isReversed => reversal != null;

  /// Whether the payment still has a financial effect.
  bool get isActive => reversal == null;

  /// Whether this is a refund.
  bool get isRefund => kind == PaymentKind.refund;

  /// Whether cash comes in (a customer pays, or a supplier refunds us).
  bool get isMoneyIn => (partyType == PartyType.customer) == !isRefund;

  /// Sum of the (signed) invoice allocations.
  Money get allocatedTotal => Money.sum(
    allocations.map((a) => a.amount),
    currencyCode: amount.currencyCode,
    decimalPlaces: amount.decimalPlaces,
  );

  /// A copy with changed allocations and/or reversal.
  Payment copyWith({
    List<PaymentAllocation>? allocations,
    PaymentReversal? reversal,
  }) => Payment(
    id: id,
    number: number,
    kind: kind,
    partyType: partyType,
    partyId: partyId,
    partyName: partyName,
    methodId: methodId,
    methodName: methodName,
    paymentDate: paymentDate,
    amount: amount,
    idempotencyKey: idempotencyKey,
    createdAt: createdAt,
    reference: reference,
    notes: notes,
    refundOfPaymentId: refundOfPaymentId,
    allocations: allocations ?? this.allocations,
    reversal: reversal ?? this.reversal,
  );

  @override
  List<Object?> get props => [
    id,
    number,
    kind,
    partyType,
    partyId,
    partyName,
    methodId,
    methodName,
    paymentDate,
    amount,
    idempotencyKey,
    createdAt,
    reference,
    notes,
    refundOfPaymentId,
    allocations,
    reversal,
  ];
}
