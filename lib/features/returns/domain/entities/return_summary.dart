import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// A return as shown in lists.
final class ReturnSummary extends Equatable {
  /// Creates a summary.
  const ReturnSummary({
    required this.id,
    required this.kind,
    required this.number,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.partyName,
    required this.returnDate,
    required this.total,
    required this.refundAmount,
    required this.lineCount,
  });

  /// Return id.
  final String id;

  /// Sales or purchase return.
  final InvoiceKind kind;

  /// Return number.
  final String number;

  /// Original invoice id.
  final String invoiceId;

  /// Original invoice number.
  final String invoiceNumber;

  /// Customer or supplier name.
  final String partyName;

  /// Date of the return.
  final DateTime returnDate;

  /// Total value including tax.
  final Money total;

  /// Cash handed back.
  final Money refundAmount;

  /// Number of lines.
  final int lineCount;

  @override
  List<Object?> get props => [
    id,
    kind,
    number,
    invoiceId,
    invoiceNumber,
    partyName,
    returnDate,
    total,
    refundAmount,
    lineCount,
  ];
}
