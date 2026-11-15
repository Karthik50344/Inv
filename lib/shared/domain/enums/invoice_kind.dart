/// The two kinds of invoice a payment can settle.
enum InvoiceKind {
  /// A sales invoice (money owed by a customer).
  sales('Sales invoice'),

  /// A purchase invoice (money owed to a supplier).
  purchase('Purchase invoice');

  const InvoiceKind(this.label);

  /// Label for the UI.
  final String label;
}
