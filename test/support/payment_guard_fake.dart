import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/services/invoice_payment_guard.dart';

/// An [InvoicePaymentGuard] for tests that do not involve payments: no
/// invoice ever has payment activity.
final class NoPaymentsGuard implements InvoicePaymentGuard {
  /// Creates the guard.
  const NoPaymentsGuard();

  @override
  Future<Result<bool>> hasActivePayments(InvoiceKind kind, String invoiceId) async =>
      const Result.success(false);
}

/// A guard whose answer can be switched, to test void rules.
final class SwitchableGuard implements InvoicePaymentGuard {
  /// Whether every invoice reports active payments.
  bool active = false;

  @override
  Future<Result<bool>> hasActivePayments(
    InvoiceKind kind,
    String invoiceId,
  ) async => Result.success(active);
}
