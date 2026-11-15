import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// A purchase invoice as shown in a list.
final class PurchaseSummary extends Equatable {
  /// Creates a summary.
  const PurchaseSummary({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.invoiceDate,
    required this.total,
    required this.lineCount,
    this.number,
    this.dueDate,
    this.supplierReference,
  });

  /// Invoice id.
  final String id;

  /// Document number once posted.
  final String? number;

  /// Supplier id.
  final String supplierId;

  /// Supplier name snapshot.
  final String supplierName;

  /// Lifecycle status.
  final DocumentStatus status;

  /// Invoice date.
  final DateTime invoiceDate;

  /// Due date, if any.
  final DateTime? dueDate;

  /// The supplier's own reference, if any.
  final String? supplierReference;

  /// Invoice total including tax.
  final Money total;

  /// Number of lines.
  final int lineCount;

  /// Number, or "Draft" before posting.
  String get displayNumber => number ?? 'Draft';

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
    total,
    lineCount,
  ];
}
