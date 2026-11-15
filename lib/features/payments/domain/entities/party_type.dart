import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// Who a payment is exchanged with.
enum PartyType {
  /// A customer (receipts for sales invoices).
  customer('customer', 'Customer', 'Customers', InvoiceKind.sales),

  /// A supplier (payments for purchase invoices).
  supplier('supplier', 'Supplier', 'Suppliers', InvoiceKind.purchase);

  const PartyType(this.dbName, this.label, this.pluralLabel, this.invoiceKind);

  /// Value stored in the database.
  final String dbName;

  /// Singular label for the UI.
  final String label;

  /// Plural label for the UI.
  final String pluralLabel;

  /// The invoices this party's payments settle.
  final InvoiceKind invoiceKind;

  /// Parses a stored value.
  static PartyType fromDbName(String value) => PartyType.values.firstWhere(
    (type) => type.dbName == value,
    orElse: () => throw ArgumentError.value(value, 'value', 'Unknown party'),
  );
}
