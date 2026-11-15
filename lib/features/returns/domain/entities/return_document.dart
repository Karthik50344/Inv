import 'package:equatable/equatable.dart';
import 'package:inventrix/features/returns/domain/entities/return_line.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Cash handed back as part of a return.
final class ReturnRefund extends Equatable {
  /// Creates a refund.
  const ReturnRefund({
    required this.amount,
    required this.methodId,
    required this.methodName,
    this.reference,
  });

  /// Positive amount of money that changed hands.
  final Money amount;

  /// The payment method used.
  final String methodId;

  /// Method name at the time of the return.
  final String methodName;

  /// Optional reference (transaction id, ...).
  final String? reference;

  @override
  List<Object?> get props => [amount, methodId, methodName, reference];
}

/// A posted sales or purchase return.
///
/// A return is created and posted in one step and never edited afterwards:
/// the original invoice stays exactly as it was, and the return is its own
/// numbered document (`SRN-000001` / `PRN-000001`).
///
/// Its value is a **credit note**: it lowers what the customer owes us or
/// what we owe the supplier. Whatever part of that value was paid out in
/// cash is [refund]; the rest stays as [credit].
final class ReturnDocument extends Equatable {
  /// Creates a return.
  const ReturnDocument({
    required this.id,
    required this.kind,
    required this.number,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.partyName,
    required this.returnDate,
    required this.reason,
    required this.lines,
    required this.idempotencyKey,
    required this.createdAt,
    this.partyId,
    this.notes,
    this.refund,
  });

  /// Unique id.
  final String id;

  /// Sales return or purchase return.
  final InvoiceKind kind;

  /// Document number.
  final String number;

  /// The original invoice.
  final String invoiceId;

  /// Original invoice number.
  final String invoiceNumber;

  /// Customer or supplier id; `null` for a return of a walk-in sale.
  final String? partyId;

  /// Customer or supplier name on the original invoice.
  final String partyName;

  /// Date of the return (UTC midnight of the chosen day).
  final DateTime returnDate;

  /// Why the goods came back.
  final String reason;

  /// Free-text notes.
  final String? notes;

  /// Returned lines, ordered by line number.
  final List<ReturnLine> lines;

  /// Cash handed back, if any.
  final ReturnRefund? refund;

  /// Key that makes posting safe to repeat.
  final String idempotencyKey;

  /// When the return was recorded (UTC).
  final DateTime createdAt;

  /// Whether the original sale had no customer.
  bool get isWalkIn => partyId == null;

  /// Value of the goods without tax.
  Money get net => _sum((l) => l.net);

  /// Tax on the returned goods.
  Money get tax => _sum((l) => l.tax);

  /// Total value of the return, including tax.
  Money get total => net + tax;

  /// Cash handed back (zero when none).
  Money get refundAmount => refund?.amount ?? (total - total);

  /// The part of [total] kept as credit instead of cash.
  Money get credit => total - refundAmount;

  /// Value that entered or left stock.
  Money get stockValue => _sum((l) => l.stockCost);

  /// Text to show for the document.
  String get displayNumber => number;

  Money _sum(Money Function(ReturnLine) pick) {
    final first = lines.first.net;
    return Money.sum(
      lines.map(pick),
      currencyCode: first.currencyCode,
      decimalPlaces: first.decimalPlaces,
    );
  }

  @override
  List<Object?> get props => [
    id,
    kind,
    number,
    invoiceId,
    invoiceNumber,
    partyId,
    partyName,
    returnDate,
    reason,
    notes,
    lines,
    refund,
    idempotencyKey,
    createdAt,
  ];
}
