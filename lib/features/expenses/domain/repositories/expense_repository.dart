import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_attachment.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_filter.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_summary.dart';

/// Persistence contract for expenses and their attachments.
///
/// Methods that change several records are called inside
/// `TransactionRunner.runResult` by the use cases.
abstract interface class ExpenseRepository {
  /// Lists expenses matching [filter], newest expense date first.
  Future<Result<List<ExpenseSummary>>> search(ExpenseFilter filter);

  /// Loads one expense with its attachments; `NotFoundFailure` if missing.
  Future<Result<Expense>> getById(String id);

  /// Inserts a new draft, or replaces the content of an existing draft.
  /// Attachments are not touched. Fails with `ValidationFailure` when the
  /// stored expense is not a draft.
  Future<Result<void>> saveDraft(Expense expense);

  /// Marks a draft as cancelled. Fails with `ValidationFailure` if it is no
  /// longer a draft, so a stale screen cannot overwrite a newer state.
  Future<Result<void>> markCancelled(String id, {required DateTime at});

  /// Marks a draft as posted with its [number], refreshing the category and
  /// payment method name snapshots. Fails with `ValidationFailure` unless
  /// the expense is a draft (this is what prevents double posting).
  Future<Result<void>> markPosted(
    String id, {
    required String number,
    required String categoryName,
    required String methodName,
    required DateTime at,
  });

  /// Marks a posted expense as voided. Fails with `ValidationFailure` if it
  /// is not posted.
  Future<Result<void>> markVoided(
    String id, {
    required String reason,
    required DateTime at,
  });

  /// Stores the record of an attached file.
  Future<Result<void>> addAttachment(ExpenseAttachment attachment);

  /// Removes the record of an attachment (the file is deleted separately).
  Future<Result<void>> removeAttachment(String attachmentId);

  /// Totals of the posted expenses matching [filter] (see
  /// `ExpenseReport` for the assumptions).
  Future<Result<ExpenseReport>> report(ExpenseReportFilter filter);
}
