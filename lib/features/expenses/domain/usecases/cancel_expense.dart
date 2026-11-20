import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Cancels an expense draft that will never be posted. The record is kept
/// (it shows under the "Cancelled" filter); nothing is deleted.
final class CancelExpense {
  /// Creates the use case.
  const CancelExpense({
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

  /// Cancels draft [id]. The status is re-read inside the transaction, so a
  /// stale screen cannot cancel a posted expense.
  Future<Result<Expense>> call(String id) => _transactions.runResult(() async {
    final expense = (await _expenses.getById(id)).getOrThrow();
    if (!expense.status.canTransitionTo(DocumentStatus.cancelled) ||
        !expense.isEditable) {
      throw FailureException(
        ValidationFailure(
          'A ${expense.status.label.toLowerCase()} expense cannot be '
          'cancelled. Void a posted expense instead.',
        ),
      );
    }
    final now = _clock.now();
    (await _expenses.markCancelled(id, at: now)).getOrThrow();
    (await _audit.record(
      AuditEntry(
        id: _ids.newId(),
        entityType: ExpenseNumbering.sourceType,
        entityId: id,
        action: 'cancelled',
        summary: 'Expense draft cancelled: ${expense.description}',
        occurredAt: now,
        previousValues: const {'status': 'draft'},
        newValues: const {'status': 'cancelled'},
      ),
    )).getOrThrow();
    return (await _expenses.getById(id)).getOrThrow();
  });
}
