import 'package:equatable/equatable.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// A requested allocation of (part of) a payment to an invoice.
final class AllocationRequest extends Equatable {
  /// Creates a request.
  const AllocationRequest({required this.invoiceId, required this.amount});

  /// The invoice to settle.
  final String invoiceId;

  /// Positive amount to apply.
  final Money amount;

  @override
  List<Object?> get props => [invoiceId, amount];
}

/// Everything needed to record a payment.
final class RecordPaymentInput extends Equatable {
  /// Creates an input.
  const RecordPaymentInput({
    required this.partyType,
    required this.partyId,
    required this.methodId,
    required this.amount,
    required this.paymentDate,
    required this.idempotencyKey,
    this.allocations = const [],
    this.reference,
    this.notes,
  });

  /// Customer (receipt) or supplier (payment).
  final PartyType partyType;

  /// The customer or supplier id.
  final String partyId;

  /// The payment method id.
  final String methodId;

  /// Positive amount of money exchanged.
  final Money amount;

  /// Date of the payment.
  final DateTime paymentDate;

  /// Generated once per form; recording twice with it has no second effect.
  final String idempotencyKey;

  /// Invoices to settle; any remainder stays as party credit.
  final List<AllocationRequest> allocations;

  /// Optional reference.
  final String? reference;

  /// Optional notes.
  final String? notes;

  @override
  List<Object?> get props => [
    partyType,
    partyId,
    methodId,
    amount,
    paymentDate,
    idempotencyKey,
    allocations,
    reference,
    notes,
  ];
}

/// Everything needed to refund part of a payment.
final class RecordRefundInput extends Equatable {
  /// Creates an input.
  const RecordRefundInput({
    required this.paymentId,
    required this.amount,
    required this.refundDate,
    required this.reason,
    required this.idempotencyKey,
    this.methodId,
    this.reductions = const [],
    this.reference,
  });

  /// The payment to refund from.
  final String paymentId;

  /// Positive amount handed back.
  final Money amount;

  /// Date of the refund.
  final DateTime refundDate;

  /// Why (required).
  final String reason;

  /// Generated once per form.
  final String idempotencyKey;

  /// Method used to hand the money back; defaults to the payment's method.
  final String? methodId;

  /// How much to take back off each invoice the payment settled; the rest
  /// comes out of the payment's unallocated credit.
  final List<AllocationRequest> reductions;

  /// Optional reference.
  final String? reference;

  @override
  List<Object?> get props => [
    paymentId,
    amount,
    refundDate,
    reason,
    idempotencyKey,
    methodId,
    reductions,
    reference,
  ];
}
