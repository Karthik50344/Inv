import 'package:equatable/equatable.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_line.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_totals.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Audit and stock-ledger names of purchase invoices. Their numbers come
/// from `DocumentKind.purchaseInvoice`.
abstract final class PurchaseNumbering {
  /// Audit/stock-ledger source type for purchase invoices.
  static const String sourceType = 'purchase_invoice';
}

/// A purchase invoice: a supplier, dated lines and totals.
///
/// Only [DocumentStatus.posted] invoices change stock. Posted invoices are
/// never edited; they are voided (reversed).
final class PurchaseInvoice extends Equatable {
  /// Creates an invoice.
  const PurchaseInvoice({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.invoiceDate,
    required this.lines,
    required this.totals,
    required this.createdAt,
    required this.updatedAt,
    this.number,
    this.dueDate,
    this.supplierReference,
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

  /// Supplier id.
  final String supplierId;

  /// Supplier name at the time the invoice was saved.
  final String supplierName;

  /// Lifecycle status.
  final DocumentStatus status;

  /// Invoice date (UTC midnight of the chosen day).
  final DateTime invoiceDate;

  /// Payment due date, if any.
  final DateTime? dueDate;

  /// The supplier's own invoice number, if any.
  final String? supplierReference;

  /// Free-text notes.
  final String? notes;

  /// Lines, ordered by line number.
  final List<PurchaseLine> lines;

  /// Totals (sum of the lines).
  final PurchaseTotals totals;

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

  /// Text to show for the document: its number, or "Draft".
  String get displayNumber => number ?? 'Draft';

  /// Whether the content may still be edited.
  bool get isEditable => status.isEditable;

  @override
  List<Object?> get props => [
    id,
    number,
    supplierId,
    supplierName,
    status,
    invoiceDate,
    dueDate,
    supplierReference,
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
