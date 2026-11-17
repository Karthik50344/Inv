import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_allocation.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';
import 'package:inventrix/features/payments/domain/entities/payment_position.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';

/// Hands money back against an earlier payment.
///
/// A refund is its own record (`RFD-...`). The amount is taken first from the
/// invoices the payment had settled (`reductions`, which re-opens them) and the
/// rest from the payment's unallocated credit. The original payment is never
/// edited.
final class RecordRefund {
  /// Creates the use case.
  const RecordRefund({
    required PaymentRepository payments,
    required PaymentMethodRepository methods,
    required DocumentSequenceRepository sequences,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _payments = payments,
       _methods = methods,
       _sequences = sequences,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final PaymentRepository _payments;
  final PaymentMethodRepository _methods;
  final DocumentSequenceRepository _sequences;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Records the refund, or returns the earlier one for the same key.
  Future<Result<Payment>> call(RecordRefundInput input) async {
    final reasonError = Validators.requiredText(
      input.reason,
      label: 'Reason',
      maxLength: 200,
    );
    if (reasonError != null) {
      return Result.failure(
        ValidationFailure(reasonError, fieldErrors: {'reason': reasonError}),
      );
    }
    final reason = input.reason.trim();
    return _transactions.runResult(() async {
      final key = input.idempotencyKey.trim();
      if (key.isEmpty) {
        throw const FailureException(
          ValidationFailure('A refund needs an idempotency key.'),
        );
      }
      final existing = (await _payments.findByIdempotencyKey(key)).getOrThrow();
      if (existing != null) {
        final same =
            existing.kind == PaymentKind.refund &&
            existing.refundOfPaymentId == input.paymentId &&
            existing.amount == input.amount;
        if (!same) {
          throw const FailureException(
            ValidationFailure(
              'This refund key was already used for a different refund.',
            ),
          );
        }
        return existing;
      }

      final payment = (await _payments.getById(input.paymentId)).getOrThrow();
      if (payment.isRefund) {
        throw const FailureException(
          ValidationFailure('A refund cannot be refunded.'),
        );
      }
      if (payment.isReversed) {
        throw const FailureException(
          ValidationFailure('A reversed payment cannot be refunded.'),
        );
      }
      final amount = input.amount;
      if (!amount.isPositive) {
        throw const FailureException(
          ValidationFailure(
            'Enter an amount greater than zero.',
            fieldErrors: {'amount': 'Enter an amount greater than zero.'},
          ),
        );
      }
      if (amount.currencyCode != payment.amount.currencyCode ||
          amount.decimalPlaces != payment.amount.decimalPlaces) {
        throw const FailureException(
          ValidationFailure('Refund currency does not match the payment.'),
        );
      }
      final refunds = (await _payments.activeRefundsOf(input.paymentId))
          .getOrThrow();
      final position = PaymentPosition.of(payment, refunds);
      if (amount > position.refundable) {
        throw FailureException(
          ValidationFailure(
            'At most ${position.refundable.toPlainString()} can still be '
            'refunded from ${payment.number}.',
            fieldErrors: {'amount': 'More than can be refunded.'},
          ),
        );
      }

      final byInvoice = {for (final a in payment.allocations) a.invoiceId: a};
      final seen = <String>{};
      var reduced = amount - amount;
      final allocations = <PaymentAllocation>[];
      final refundId = _ids.newId();
      final now = _clock.now();
      for (final reduction in input.reductions) {
        if (!seen.add(reduction.invoiceId)) {
          throw const FailureException(
            ValidationFailure('An invoice can only be reduced once.'),
          );
        }
        final original = byInvoice[reduction.invoiceId];
        if (original == null) {
          throw const FailureException(
            ValidationFailure('That invoice was not settled by this payment.'),
          );
        }
        final available = position.allocatedByInvoice[reduction.invoiceId] ?? 0;
        if (!reduction.amount.isPositive ||
            reduction.amount.minorUnits > available ||
            reduction.amount.currencyCode != amount.currencyCode) {
          throw FailureException(
            ValidationFailure(
              'The reduction for ${original.invoiceNumber} must be between '
              'zero and what this payment still settles.',
            ),
          );
        }
        reduced += reduction.amount;
        allocations.add(
          PaymentAllocation(
            id: _ids.newId(),
            paymentId: refundId,
            invoiceKind: original.invoiceKind,
            invoiceId: original.invoiceId,
            invoiceNumber: original.invoiceNumber,
            amount: reduction.amount.negate(),
            createdAt: now,
          ),
        );
      }
      if (reduced > amount) {
        throw const FailureException(
          ValidationFailure(
            'The reductions are more than the amount being refunded.',
          ),
        );
      }
      final fromCredit = amount - reduced;
      if (fromCredit > position.credit) {
        throw FailureException(
          ValidationFailure(
            'Only ${position.credit.toPlainString()} of this payment is '
            'unallocated. Reduce the invoices it settled to refund more.',
          ),
        );
      }

      final method = (await _methods.getById(
        input.methodId ?? payment.methodId,
      )).getOrThrow();
      final number = (await _sequences.nextNumber(DocumentKind.refund))
          .getOrThrow();
      final reference = input.reference?.trim();
      final refund = Payment(
        id: refundId,
        number: number,
        kind: PaymentKind.refund,
        partyType: payment.partyType,
        partyId: payment.partyId,
        partyName: payment.partyName,
        methodId: method.id,
        methodName: method.name,
        paymentDate: input.refundDate,
        amount: amount,
        idempotencyKey: key,
        createdAt: now,
        reference: (reference == null || reference.isEmpty) ? null : reference,
        notes: reason,
        refundOfPaymentId: payment.id,
        allocations: allocations,
      );
      (await _payments.insert(refund)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: PaymentNumbering.auditType,
          entityId: refundId,
          action: 'refunded',
          summary:
              'Refunded ${amount.toString()} of ${payment.number}: $reason',
          occurredAt: now,
        ),
      )).getOrThrow();
      return (await _payments.getById(refundId)).getOrThrow();
    });
  }
}
