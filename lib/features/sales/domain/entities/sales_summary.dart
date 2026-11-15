import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// A sale invoice as shown in a list.
final class SalesSummary extends Equatable {
  /// Creates a summary.
  const SalesSummary({
    required this.id,
    required this.customerName,
    required this.status,
    required this.invoiceDate,
    required this.total,
    required this.lineCount,
    this.number,
    this.dueDate,
    this.customerId,
    this.customerReference,
  });

  /// Invoice id.
  final String id;

  /// Document number once posted.
  final String? number;

  /// Customer id; `null` for a walk-in sale.
  final String? customerId;

  /// Customer name snapshot.
  final String customerName;

  /// Lifecycle status.
  final DocumentStatus status;

  /// Invoice date.
  final DateTime invoiceDate;

  /// Due date, if any.
  final DateTime? dueDate;

  /// The customer's own reference, if any.
  final String? customerReference;

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
    customerId,
    customerName,
    status,
    invoiceDate,
    dueDate,
    customerReference,
    total,
    lineCount,
  ];
}
