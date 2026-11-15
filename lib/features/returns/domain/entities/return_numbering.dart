import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// Where return numbers, stock-ledger sources and audit entries come from.
abstract final class ReturnNumbering {
  /// Key of the gap-free document sequence of [kind].
  static String sequenceKey(InvoiceKind kind) => switch (kind) {
    InvoiceKind.sales => 'sales_return',
    InvoiceKind.purchase => 'purchase_return',
  };

  /// Prefix of the formatted number (`SRN-000001`, `PRN-000001`).
  static String prefix(InvoiceKind kind) => switch (kind) {
    InvoiceKind.sales => 'SRN-',
    InvoiceKind.purchase => 'PRN-',
  };

  /// Stock-ledger source type and audit entity type of [kind].
  static String sourceType(InvoiceKind kind) => switch (kind) {
    InvoiceKind.sales => 'sales_return',
    InvoiceKind.purchase => 'purchase_return',
  };

  /// Label of a return of [kind].
  static String label(InvoiceKind kind) => switch (kind) {
    InvoiceKind.sales => 'Sales return',
    InvoiceKind.purchase => 'Purchase return',
  };
}
