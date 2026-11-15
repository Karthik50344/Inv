import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_attachment.dart';
import 'package:inventrix/features/expenses/domain/repositories/attachment_storage.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Attaches a receipt file to an expense.
///
/// Receipts often arrive after an expense is posted, so attaching is allowed
/// for drafts and posted expenses (never for cancelled or voided ones).
final class AddExpenseAttachment {
  /// Creates the use case.
  const AddExpenseAttachment({
    required ExpenseRepository expenses,
    required AttachmentStorage storage,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _expenses = expenses,
       _storage = storage,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final ExpenseRepository _expenses;
  final AttachmentStorage _storage;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Most files one expense can have.
  static const int maxAttachments = 10;

  /// Copies the file at [sourcePath] into app storage and records it on
  /// expense [expenseId]. Returns the updated expense.
  Future<Result<Expense>> call(String expenseId, String sourcePath) async {
    final loaded = await _expenses.getById(expenseId);
    final expense = loaded.valueOrNull;
    if (expense == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    final blocked = _blockedReason(expense);
    if (blocked != null) {
      return Result.failure(ValidationFailure(blocked));
    }

    // Copy first: a file copy cannot be rolled back, so if the database
    // write fails below the copy is deleted again.
    final storedResult = await _storage.store(sourcePath);
    final stored = storedResult.valueOrNull;
    if (stored == null) {
      return Result.failure(storedResult.failureOrNull!);
    }

    final now = _clock.now();
    final attachment = ExpenseAttachment(
      id: _ids.newId(),
      expenseId: expenseId,
      fileName: stored.fileName,
      storedPath: stored.relativePath,
      mimeType: stored.mimeType,
      sizeBytes: stored.sizeBytes,
      createdAt: now,
    );
    final result = await _transactions.runResult(() async {
      // Re-check inside the transaction: the expense may have changed.
      final current = (await _expenses.getById(expenseId)).getOrThrow();
      final problem = _blockedReason(current);
      if (problem != null) {
        throw FailureException(ValidationFailure(problem));
      }
      (await _expenses.addAttachment(attachment)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: ExpenseNumbering.sourceType,
          entityId: expenseId,
          action: 'attachment_added',
          summary:
              'Attached ${attachment.fileName} to ${current.displayNumber}',
          occurredAt: now,
        ),
      )).getOrThrow();
      return (await _expenses.getById(expenseId)).getOrThrow();
    });
    if (result.isFailure) {
      await _storage.delete(stored.relativePath);
    }
    return result;
  }

  String? _blockedReason(Expense expense) {
    if (expense.status != DocumentStatus.draft &&
        expense.status != DocumentStatus.posted) {
      return 'Files can only be attached to draft or posted expenses.';
    }
    if (expense.attachments.length >= maxAttachments) {
      return 'An expense can have at most $maxAttachments attachments.';
    }
    return null;
  }
}

/// Removes an attachment from an expense draft.
///
/// Once an expense is posted its attachments are evidence and stay: the
/// database refuses to delete them.
final class RemoveExpenseAttachment {
  /// Creates the use case.
  const RemoveExpenseAttachment({
    required ExpenseRepository expenses,
    required AttachmentStorage storage,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _expenses = expenses,
       _storage = storage,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final ExpenseRepository _expenses;
  final AttachmentStorage _storage;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Removes [attachmentId] from draft expense [expenseId]. Returns the
  /// updated expense.
  Future<Result<Expense>> call(String expenseId, String attachmentId) async {
    String? removedPath;
    final result = await _transactions.runResult(() async {
      final expense = (await _expenses.getById(expenseId)).getOrThrow();
      if (!expense.isEditable) {
        throw const FailureException(
          ValidationFailure(
            'Attachments of a posted expense are kept as evidence and '
            'cannot be removed.',
          ),
        );
      }
      final attachment = expense.attachments
          .where((a) => a.id == attachmentId)
          .firstOrNull;
      if (attachment == null) {
        throw const FailureException(
          NotFoundFailure('This attachment no longer exists.'),
        );
      }
      (await _expenses.removeAttachment(attachmentId)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: ExpenseNumbering.sourceType,
          entityId: expenseId,
          action: 'attachment_removed',
          summary: 'Removed ${attachment.fileName} from a draft expense',
          occurredAt: _clock.now(),
        ),
      )).getOrThrow();
      removedPath = attachment.storedPath;
      return (await _expenses.getById(expenseId)).getOrThrow();
    });
    final path = removedPath;
    if (result.isSuccess && path != null) {
      await _storage.delete(path);
    }
    return result;
  }
}
