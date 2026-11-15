import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_allocation.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/entities/payment_position.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/services/allocation_checker.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Applies the unallocated credit of an existing payment to invoices.
///
/// Repeating a request cannot over-allocate: every call re-checks the
/// remaining credit and each invoice's outstanding amount.
final class AllocatePaymentCredit {
  /// Creates the use case.
  const AllocatePaymentCredit({
    required PaymentRepository payments,
    required AllocationChecker allocations,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _payments = payments,
       _allocations = allocations,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final PaymentRepository _payments;
  final AllocationChecker _allocations;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Allocates [requests] from the credit of payment [paymentId].
  Future<Result<Payment>> call(
    String paymentId,
    List<AllocationRequest> requests,
  ) => _transactions.runResult(() async {
    if (requests.isEmpty) {
      throw const FailureException(
        ValidationFailure('Choose at least one invoice.'),
      );
    }
    final payment = (await _payments.getById(paymentId)).getOrThrow();
    if (payment.isRefund) {
      throw const FailureException(
        ValidationFailure('A refund has no credit to allocate.'),
      );
    }
    if (payment.isReversed) {
      throw const FailureException(
        ValidationFailure('A reversed payment cannot be allocated.'),
      );
    }
    final refunds = (await _payments.activeRefundsOf(paymentId)).getOrThrow();
    final position = PaymentPosition.of(payment, refunds);
    if (!position.credit.isPositive) {
      throw const FailureException(
        ValidationFailure('This payment has no unallocated credit left.'),
      );
    }
    final resolved = await _allocations.resolve(
      partyType: payment.partyType,
      partyId: payment.partyId,
      requests: requests,
      limit: position.credit,
    );
    final now = _clock.now();
    (await _payments.insertAllocations([
      for (final r in resolved)
        PaymentAllocation(
          id: _ids.newId(),
          paymentId: paymentId,
          invoiceKind: payment.partyType.invoiceKind,
          invoiceId: r.invoice.id,
          invoiceNumber: r.invoice.displayNumber,
          amount: r.amount,
          createdAt: now,
        ),
    ])).getOrThrow();
    (await _audit.record(
      AuditEntry(
        id: _ids.newId(),
        entityType: PaymentNumbering.auditType,
        entityId: paymentId,
        action: 'allocated',
        summary:
            'Allocated credit of ${payment.number} to '
            '${resolved.length} invoice(s).',
        occurredAt: now,
      ),
    )).getOrThrow();
    return (await _payments.getById(paymentId)).getOrThrow();
  });
}
