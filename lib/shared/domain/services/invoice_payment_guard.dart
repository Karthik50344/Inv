import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// Lets the sales and purchase features ask whether an invoice has payment
/// activity, without depending on the payments feature (which itself depends
/// on sales and purchases). Implemented by the payments data layer.
abstract interface class InvoicePaymentGuard {
  /// Whether at least one payment or refund that has not been reversed is
  /// allocated to the invoice. Such an invoice cannot be voided until those
  /// payments are reversed.
  Future<Result<bool>> hasActivePayments(InvoiceKind kind, String invoiceId);
}
