import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_reversal.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/services/invoice_ledger.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Cancels the financial effect of a payment or refund without deleting it.
///
/// Balances and invoice statuses are derived from active payments, so they
/// recalculate by themselves once the reversal is recorded.
final class ReversePayment {
  /// Creates the use case.
  const ReversePayment({
    required PaymentRepository payments,
    required InvoiceLedger ledger,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _payments = payments,
       _ledger = ledger,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final PaymentRepository _payments;
  final InvoiceLedger _ledger;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Reverses payment [paymentId] with a mandatory [reason].
  Future<Result<Payment>> call(
    String paymentId, {
    required String reason,
  }) async {
    final reasonError = Validators.requiredText(
      reason,
      label: 'Reason',
      maxLength: 200,
    );
    if (reasonError != null) {
      return Result.failure(
        ValidationFailure(reasonError, fieldErrors: {'reason': reasonError}),
      );
    }
    final trimmed = reason.trim();
    return _transactions.runResult(() async {
      final payment = (await _payments.getById(paymentId)).getOrThrow();
      if (payment.isReversed) {
        throw const FailureException(
          ValidationFailure('This payment has already been reversed.'),
        );
      }
      if (payment.isRefund) {
        // Undoing a refund puts money back on the invoices it reduced. Make
        // sure that does not push any invoice past its total.
        for (final allocation in payment.allocations) {
          final invoice = (await _ledger.get(
            allocation.invoiceKind,
            allocation.invoiceId,
          )).getOrThrow();
          if (allocation.amount.abs() > invoice.outstanding) {
            throw FailureException(
              ValidationFailure(
                '${invoice.displayNumber} has been paid again since this '
                'refund, so the refund cannot be reversed.',
              ),
            );
          }
        }
      } else {
        final refunds = (await _payments.activeRefundsOf(
          paymentId,
        )).getOrThrow();
        if (refunds.isNotEmpty) {
          throw FailureException(
            ValidationFailure(
              'Reverse its refund(s) first: '
              '${refunds.map((r) => r.number).join(', ')}.',
            ),
          );
        }
      }
      final now = _clock.now();
      (await _payments.insertReversal(
        PaymentReversal(
          id: _ids.newId(),
          paymentId: paymentId,
          reason: trimmed,
          reversedAt: now,
        ),
      )).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: PaymentNumbering.auditType,
          entityId: paymentId,
          action: 'reversed',
          summary: 'Reversed ${payment.number}: $trimmed',
          occurredAt: now,
        ),
      )).getOrThrow();
      return (await _payments.getById(paymentId)).getOrThrow();
    });
  }
}
