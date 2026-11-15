import 'package:equatable/equatable.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_status.dart';

/// An invoice, its derived payment status and the payments settling it.
final class InvoiceSettlementView extends Equatable {
  /// Creates a view.
  const InvoiceSettlementView({
    required this.invoice,
    required this.status,
    required this.payments,
  });

  /// The invoice with paid/outstanding amounts.
  final OpenInvoice invoice;

  /// Derived status; `null` unless the invoice is posted.
  final PaymentStatus? status;

  /// Active payments and refunds allocated to the invoice, newest first.
  final List<Payment> payments;

  @override
  List<Object?> get props => [invoice, status, payments];
}
