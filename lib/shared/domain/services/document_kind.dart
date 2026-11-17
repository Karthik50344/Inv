/// Keys of the numbering settings shared by every document kind.
abstract final class NumberingSettingKeys {
  /// Digits the counters are padded to (`app_settings` key).
  static const String padding = 'numbering.padding';
}

/// Every kind of numbered document, with its gap-free counter and the
/// prefix used until the owner chooses another one.
enum DocumentKind {
  /// Sales invoices.
  salesInvoice(
    sequenceKey: 'sales_invoice',
    defaultPrefix: 'INV-',
    label: 'Sales invoices',
  ),

  /// Purchase invoices.
  purchaseInvoice(
    sequenceKey: 'purchase_invoice',
    defaultPrefix: 'PUR-',
    label: 'Purchase invoices',
  ),

  /// Payments received or made.
  payment(sequenceKey: 'payment', defaultPrefix: 'PAY-', label: 'Payments'),

  /// Refunds.
  refund(sequenceKey: 'refund', defaultPrefix: 'RFD-', label: 'Refunds'),

  /// Sales returns.
  salesReturn(
    sequenceKey: 'sales_return',
    defaultPrefix: 'SRN-',
    label: 'Sales returns',
  ),

  /// Purchase returns.
  purchaseReturn(
    sequenceKey: 'purchase_return',
    defaultPrefix: 'PRN-',
    label: 'Purchase returns',
  ),

  /// Expenses.
  expense(sequenceKey: 'expense', defaultPrefix: 'EXP-', label: 'Expenses');

  const DocumentKind({
    required this.sequenceKey,
    required this.defaultPrefix,
    required this.label,
  });

  /// Key of the row in `document_sequences`. Never change these values:
  /// they name counters that already exist on users' devices.
  final String sequenceKey;

  /// Prefix used until the owner changes it.
  final String defaultPrefix;

  /// Name shown in the settings screen.
  final String label;

  /// Key under which the prefix is stored in `app_settings`.
  String get prefixSettingKey => 'numbering.prefix.$sequenceKey';
}
