/// Settlement state of a posted invoice. Always derived from invoice total,
/// payment allocations, refunds and due date; never stored, and unrelated to
/// the document status (draft, posted, ...).
enum PaymentStatus {
  /// Nothing paid and not yet due (or no due date).
  unpaid('Unpaid'),

  /// Part of the total is paid and the invoice is not past due.
  partiallyPaid('Partially paid'),

  /// The total is covered.
  paid('Paid'),

  /// An amount is outstanding and the due date has passed.
  overdue('Overdue'),

  /// Part of the money received was handed back; the invoice is still
  /// partly paid.
  partiallyRefunded('Partially refunded'),

  /// Everything received was handed back; nothing is paid.
  refunded('Refunded'),

  /// Reserved: write-offs are not supported yet, so this is never derived.
  writtenOff('Written off');

  const PaymentStatus(this.label);

  /// Label for the UI.
  final String label;

  /// Whether nothing remains to be paid.
  bool get isSettled => this == paid || this == writtenOff;
}
