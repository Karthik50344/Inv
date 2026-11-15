import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Voids a posted expense with a mandatory reason.
///
/// The posted figures stay on record (database triggers forbid changing
/// them); the expense simply stops counting in the reports. Its number is
/// not reused.
final class VoidExpense {
  /// Creates the use case.
  const VoidExpense({
    required ExpenseRepository expenses,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _expenses = expenses,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final ExpenseRepository _expenses;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Voids expense [id]; a [reason] is mandatory.
  Future<Result<Expense>> call(String id, {required String reason}) async {
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
      final expense = (await _expenses.getById(id)).getOrThrow();
      if (expense.status != DocumentStatus.posted) {
        throw FailureException(
          ValidationFailure(
            'Only posted expenses can be voided '
            '(this one is ${expense.status.label.toLowerCase()}).',
          ),
        );
      }
      final now = _clock.now();
      (await _expenses.markVoided(id, reason: trimmed, at: now)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: ExpenseNumbering.sourceType,
          entityId: id,
          action: 'voided',
          summary: 'Voided ${expense.displayNumber}: $trimmed',
          occurredAt: now,
        ),
      )).getOrThrow();
      return (await _expenses.getById(id)).getOrThrow();
    });
  }
}
