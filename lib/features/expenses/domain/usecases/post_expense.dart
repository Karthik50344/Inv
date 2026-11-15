import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_category_repository.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/domain/services/expense_integrity.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';

/// Posts an expense: re-validates it, assigns its gap-free number and marks
/// it posted, all in one transaction.
///
/// Posting is what makes an expense count in the reports. It does not touch
/// inventory. A second post of the same expense fails (its status is no
/// longer a draft), so it can never be counted twice, and the number is not
/// consumed when anything in the transaction fails.
final class PostExpense {
  /// Creates the use case.
  const PostExpense({
    required ExpenseRepository expenses,
    required ExpenseCategoryRepository categories,
    required PaymentMethodRepository methods,
    required DocumentSequenceRepository sequences,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _expenses = expenses,
       _categories = categories,
       _methods = methods,
       _sequences = sequences,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final ExpenseRepository _expenses;
  final ExpenseCategoryRepository _categories;
  final PaymentMethodRepository _methods;
  final DocumentSequenceRepository _sequences;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Posts expense [id] and returns the posted expense.
  Future<Result<Expense>> call(String id) => _transactions.runResult(() async {
    // 1. The document and its status.
    final expense = (await _expenses.getById(id)).getOrThrow();
    if (expense.status == DocumentStatus.posted) {
      throw const FailureException(
        ValidationFailure('This expense is already posted.'),
      );
    }
    if (!expense.status.canTransitionTo(DocumentStatus.posted)) {
      throw FailureException(
        ValidationFailure(
          'A ${expense.status.label.toLowerCase()} expense cannot be posted.',
        ),
      );
    }
    final problem = ExpenseIntegrity.findProblem(expense);
    if (problem != null) {
      throw FailureException(ValidationFailure(problem));
    }

    // 2. The things it refers to must still be usable.
    final category = (await _categories.getById(expense.categoryId))
        .getOrThrow();
    if (category.isArchived) {
      throw FailureException(
        ValidationFailure(
          '${category.name} is archived. Edit the draft and choose another '
          'category, or restore this one.',
        ),
      );
    }
    final method = (await _methods.getById(expense.methodId)).getOrThrow();
    if (method.isArchived) {
      throw FailureException(
        ValidationFailure(
          '${method.name} is archived. Edit the draft and choose another '
          'payment method.',
        ),
      );
    }

    // 3. Number, status and audit: all inside this transaction.
    final now = _clock.now();
    final sequence = (await _sequences.next(ExpenseNumbering.sequenceKey))
        .getOrThrow();
    final number = DocumentNumber.format(ExpenseNumbering.prefix, sequence);
    (await _expenses.markPosted(
      id,
      number: number,
      categoryName: category.name,
      methodName: method.name,
      at: now,
    )).getOrThrow();
    (await _audit.record(
      AuditEntry(
        id: _ids.newId(),
        entityType: ExpenseNumbering.sourceType,
        entityId: id,
        action: 'posted',
        summary:
            'Posted $number: ${expense.description} '
            '(${category.name}), total ${expense.amounts.total}',
        occurredAt: now,
      ),
    )).getOrThrow();
    return (await _expenses.getById(id)).getOrThrow();
  });
}
