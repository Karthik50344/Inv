import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_allocation.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/services/allocation_checker.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';

/// Records money received from a customer or paid to a supplier, optionally
/// settling invoices in the same transaction.
///
/// Whatever is not allocated stays on the payment as party credit and can be
/// allocated later ([AllocatePaymentCredit]).
final class RecordPayment {
  /// Creates the use case.
  const RecordPayment({
    required PaymentRepository payments,
    required PaymentMethodRepository methods,
    required PartyDirectory parties,
    required AllocationChecker allocations,
    required SettingsRepository settings,
    required DocumentSequenceRepository sequences,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _payments = payments,
       _methods = methods,
       _parties = parties,
       _allocations = allocations,
       _settings = settings,
       _sequences = sequences,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final PaymentRepository _payments;
  final PaymentMethodRepository _methods;
  final PartyDirectory _parties;
  final AllocationChecker _allocations;
  final SettingsRepository _settings;
  final DocumentSequenceRepository _sequences;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Records the payment, or returns the earlier one if
  /// `input.idempotencyKey` was already used for the same request.
  Future<Result<Payment>> call(RecordPaymentInput input) =>
      _transactions.runResult(() async {
        final key = input.idempotencyKey.trim();
        if (key.isEmpty) {
          throw const FailureException(
            ValidationFailure('A payment needs an idempotency key.'),
          );
        }
        final existing = (await _payments.findByIdempotencyKey(key))
            .getOrThrow();
        if (existing != null) {
          final same =
              existing.kind == PaymentKind.payment &&
              existing.partyType == input.partyType &&
              existing.partyId == input.partyId &&
              existing.amount == input.amount;
          if (!same) {
            throw const FailureException(
              ValidationFailure(
                'This payment key was already used for a different payment.',
              ),
            );
          }
          return existing;
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
        final currency = (await _settings.getCurrencyConfig()).getOrThrow();
        if (amount.currencyCode != currency.currencyCode ||
            amount.decimalPlaces != currency.decimalPlaces) {
          throw FailureException(
            ValidationFailure(
              'Payments are recorded in ${currency.currencyCode}.',
            ),
          );
        }
        final method = (await _methods.getById(input.methodId)).getOrThrow();
        if (method.isArchived) {
          throw const FailureException(
            ValidationFailure(
              'This payment method is archived.',
              fieldErrors: {'method': 'Choose an active payment method.'},
            ),
          );
        }
        final party = (await _parties.get(
          input.partyType,
          input.partyId,
        )).getOrThrow();
        final resolved = await _allocations.resolve(
          partyType: input.partyType,
          partyId: input.partyId,
          requests: input.allocations,
          limit: amount,
        );

        final now = _clock.now();
        final number = (await _sequences.nextNumber(DocumentKind.payment))
            .getOrThrow();
        final id = _ids.newId();
        final payment = Payment(
          id: id,
          number: number,
          kind: PaymentKind.payment,
          partyType: party.type,
          partyId: party.id,
          partyName: party.name,
          methodId: method.id,
          methodName: method.name,
          paymentDate: input.paymentDate,
          amount: amount,
          idempotencyKey: key,
          createdAt: now,
          reference: _clean(input.reference),
          notes: _clean(input.notes),
          allocations: [
            for (final r in resolved)
              PaymentAllocation(
                id: _ids.newId(),
                paymentId: id,
                invoiceKind: party.type.invoiceKind,
                invoiceId: r.invoice.id,
                invoiceNumber: r.invoice.displayNumber,
                amount: r.amount,
                createdAt: now,
              ),
          ],
        );
        (await _payments.insert(payment)).getOrThrow();
        (await _audit.record(
          AuditEntry(
            id: _ids.newId(),
            entityType: PaymentNumbering.auditType,
            entityId: id,
            action: 'recorded',
            summary:
                'Recorded $number (${party.type.label.toLowerCase()}): '
                '${amount.toString()}, ${resolved.length} invoice(s) settled.',
            occurredAt: now,
          ),
        )).getOrThrow();
        return (await _payments.getById(id)).getOrThrow();
      });

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}
