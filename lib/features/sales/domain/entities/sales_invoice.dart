import 'package:equatable/equatable.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/features/sales/domain/entities/sales_totals.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Audit and stock-ledger names of sales invoices. Their numbers come from
/// `DocumentKind.salesInvoice`.
abstract final class SalesNumbering {
  /// Audit/stock-ledger source type for sales invoices.
  static const String sourceType = 'sales_invoice';
}

/// A sales invoice: an optional customer, dated lines and totals.
///
/// A sale without a customer is a walk-in (cash) sale: [customerId] is
/// `null` and [customerName] holds [walkInCustomerName].
///
/// Only [DocumentStatus.posted] invoices change stock. Posted invoices are
/// never edited; they are voided (reversed).
final class SalesInvoice extends Equatable {
  /// Creates an invoice.
  const SalesInvoice({
    required this.id,
    required this.customerName,
    required this.status,
    required this.invoiceDate,
    required this.lines,
    required this.totals,
    required this.createdAt,
    required this.updatedAt,
    this.number,
    this.customerId,
    this.dueDate,
    this.customerReference,
    this.notes,
    this.postedAt,
    this.cancelledAt,
    this.voidedAt,
    this.voidReason,
  });

  /// Unique id.
  final String id;

  /// Document number, assigned when posted; `null` before.
  final String? number;

  /// Customer id; `null` for a walk-in sale.
  final String? customerId;

  /// Customer name at the time the invoice was saved
  /// ([walkInCustomerName] without a customer).
  final String customerName;

  /// Lifecycle status.
  final DocumentStatus status;

  /// Invoice date (UTC midnight of the chosen day).
  final DateTime invoiceDate;

  /// Payment due date, if any.
  final DateTime? dueDate;

  /// The customer's own invoice number, if any.
  final String? customerReference;

  /// Free-text notes.
  final String? notes;

  /// Lines, ordered by line number.
  final List<SalesLine> lines;

  /// Totals (sum of the lines).
  final SalesTotals totals;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Last update time (UTC).
  final DateTime updatedAt;

  /// When it was posted.
  final DateTime? postedAt;

  /// When it was cancelled (never posted).
  final DateTime? cancelledAt;

  /// When it was voided (reversed after posting).
  final DateTime? voidedAt;

  /// Why it was voided.
  final String? voidReason;

  /// Name recorded for sales without a customer.
  static const String walkInCustomerName = 'Walk-in customer';

  /// Text to show for the document: its number, or "Draft".
  String get displayNumber => number ?? 'Draft';

  /// Whether the content may still be edited.
  bool get isEditable => status.isEditable;

  @override
  List<Object?> get props => [
    id,
    number,
    customerId,
    customerName,
    status,
    invoiceDate,
    dueDate,
    customerReference,
    notes,
    lines,
    totals,
    createdAt,
    updatedAt,
    postedAt,
    cancelledAt,
    voidedAt,
    voidReason,
  ];
}
