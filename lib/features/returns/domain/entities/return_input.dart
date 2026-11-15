import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// Raw (text) input for one returned line.
final class ReturnLineInput extends Equatable {
  /// Creates a line input.
  const ReturnLineInput({
    required this.invoiceLineId,
    required this.quantity,
    this.restock = true,
    this.note = '',
  });

  /// The line of the original invoice.
  final String invoiceLineId;

  /// Quantity text, within the unit's precision. Blank or zero means the
  /// line is not returned.
  final String quantity;

  /// Sales returns: whether the goods go back into stock (turn off for
  /// damaged goods). Ignored for purchase returns, which always leave stock.
  final bool restock;

  /// Optional note about this line.
  final String note;

  @override
  List<Object?> get props => [invoiceLineId, quantity, restock, note];
}

/// Raw input for posting a return.
final class ReturnInput extends Equatable {
  /// Creates an input.
  const ReturnInput({
    required this.kind,
    required this.invoiceId,
    required this.returnDate,
    required this.reason,
    required this.lines,
    required this.idempotencyKey,
    this.notes = '',
    this.refundAmount = '',
    this.refundMethodId,
    this.refundReference = '',
  });

  /// Sales or purchase return.
  final InvoiceKind kind;

  /// The invoice being returned against.
  final String invoiceId;

  /// Date of the return.
  final DateTime? returnDate;

  /// Why the goods came back (required).
  final String reason;

  /// Free-text notes.
  final String notes;

  /// Returned lines.
  final List<ReturnLineInput> lines;

  /// Cash handed back, as text; blank means none (the whole value stays as
  /// credit). A return of a walk-in sale always hands the whole value back.
  final String refundAmount;

  /// Method used for the cash refund.
  final String? refundMethodId;

  /// Optional reference of the cash refund.
  final String refundReference;

  /// Generated once per form; posting twice with it has no second effect.
  final String idempotencyKey;

  @override
  List<Object?> get props => [
    kind,
    invoiceId,
    returnDate,
    reason,
    notes,
    lines,
    refundAmount,
    refundMethodId,
    refundReference,
    idempotencyKey,
  ];
}
