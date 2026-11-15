import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// The part of a payment applied to one invoice.
///
/// [amount] is positive for a payment and negative for a refund (a refund
/// takes money back off an invoice). Exactly one invoice is referenced.
final class PaymentAllocation extends Equatable {
  /// Creates an allocation.
  const PaymentAllocation({
    required this.id,
    required this.paymentId,
    required this.invoiceKind,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amount,
    required this.createdAt,
  });

  /// Unique id.
  final String id;

  /// The payment (or refund) this belongs to.
  final String paymentId;

  /// Sales or purchase invoice.
  final InvoiceKind invoiceKind;

  /// The invoice id.
  final String invoiceId;

  /// The invoice number at the time of allocation.
  final String invoiceNumber;

  /// Signed amount applied to the invoice.
  final Money amount;

  /// When the allocation was made (UTC).
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    paymentId,
    invoiceKind,
    invoiceId,
    invoiceNumber,
    amount,
    createdAt,
  ];
}
