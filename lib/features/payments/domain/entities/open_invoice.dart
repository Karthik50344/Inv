import 'package:equatable/equatable.dart';
import 'package:inventrix/features/payments/domain/entities/payment_status.dart';
import 'package:inventrix/features/payments/domain/services/payment_status_calculator.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// An invoice together with what has been settled against it.
final class OpenInvoice extends Equatable {
  /// Creates an invoice view.
  const OpenInvoice({
    required this.kind,
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.documentStatus,
    required this.invoiceDate,
    required this.total,
    required this.netPaid,
    required this.refunded,
    required this.returned,
    required this.returnRefunded,
    this.number,
    this.dueDate,
  });

  /// Sales or purchase.
  final InvoiceKind kind;

  /// Invoice id.
  final String id;

  /// Customer or supplier id (empty for a walk-in sale).
  final String partyId;

  /// Customer or supplier name snapshot.
  final String partyName;

  /// Document status of the invoice.
  final DocumentStatus documentStatus;

  /// Invoice number once posted.
  final String? number;

  /// Invoice date.
  final DateTime invoiceDate;

  /// Payment due date, if any.
  final DateTime? dueDate;

  /// Invoice total including tax.
  final Money total;

  /// Payments minus refunds allocated.
  final Money netPaid;

  /// Total refunded (payment refunds only).
  final Money refunded;

  /// Value of the returns posted against the invoice (credit notes,
  /// including tax).
  final Money returned;

  /// Cash handed back through those returns.
  final Money returnRefunded;

  /// Number for display.
  String get displayNumber => number ?? 'Draft';

  /// What the party has to pay after returns: the total minus returned
  /// value.
  Money get receivable => total - returned;

  /// Money received for this invoice and kept: payments minus refunds minus
  /// cash handed back through returns.
  Money get cashHeld => netPaid - returnRefunded;

  /// What is still to be paid (never negative).
  Money get outstanding {
    final left = receivable - cashHeld;
    return left.isNegative ? total - total : left;
  }

  /// Money held beyond what is owed, for example after a return of an
  /// invoice that was already paid (never negative).
  Money get credit {
    final extra = cashHeld - receivable;
    return extra.isNegative ? total - total : extra;
  }

  /// Derived settlement status; `null` unless the invoice is posted.
  ///
  /// Returns lower the amount to settle and cash handed back through them
  /// counts as refunded money.
  PaymentStatus? statusAt(DateTime now) => PaymentStatusCalculator.derive(
    documentStatus: documentStatus,
    total: receivable,
    netPaid: cashHeld,
    refunded: refunded + returnRefunded,
    dueDate: dueDate,
    now: now,
  );

  @override
  List<Object?> get props => [
    kind,
    id,
    partyId,
    partyName,
    documentStatus,
    number,
    invoiceDate,
    dueDate,
    total,
    netPaid,
    refunded,
    returned,
    returnRefunded,
  ];
}
