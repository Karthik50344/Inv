import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';

/// Where return numbers, stock-ledger sources and audit entries come from.
abstract final class ReturnNumbering {
  /// Numbered document kind of a return of [kind]; the configured prefix
  /// (`SRN-` / `PRN-` unless changed in the settings) comes from there.
  static DocumentKind documentKind(InvoiceKind kind) => switch (kind) {
    InvoiceKind.sales => DocumentKind.salesReturn,
    InvoiceKind.purchase => DocumentKind.purchaseReturn,
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
