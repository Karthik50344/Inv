/// Whether a record is a payment or a refund of (part of) a payment.
enum PaymentKind {
  /// Money received from a customer or paid to a supplier.
  payment('payment', 'Payment'),

  /// Money handed back against an earlier payment.
  refund('refund', 'Refund');

  const PaymentKind(this.dbName, this.label);

  /// Value stored in the database.
  final String dbName;

  /// Label for the UI.
  final String label;

  /// Parses a stored value.
  static PaymentKind fromDbName(String value) => PaymentKind.values.firstWhere(
    (kind) => kind.dbName == value,
    orElse: () => throw ArgumentError.value(value, 'value', 'Unknown kind'),
  );
}
