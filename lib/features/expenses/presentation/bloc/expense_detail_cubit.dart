import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/expenses/domain/usecases/cancel_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_attachments.dart';
import 'package:inventrix/features/expenses/domain/usecases/post_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/void_expense.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';

/// State of the expense detail screen.
final class ExpenseDetailState extends Equatable {
  /// Creates a state.
  const ExpenseDetailState({
    this.status = DetailStatus.loading,
    this.expense,
    this.busy = false,
    this.message,
  });

  /// Load status.
  final DetailStatus status;

  /// The expense.
  final Expense? expense;

  /// Whether an action is running.
  final bool busy;

  /// One-shot user-facing message (result of the last action).
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  ExpenseDetailState copyWith({
    DetailStatus? status,
    Expense? expense,
    bool? busy,
    String? message,
  }) => ExpenseDetailState(
    status: status ?? this.status,
    expense: expense ?? this.expense,
    busy: busy ?? this.busy,
    message: message,
  );

  @override
  List<Object?> get props => [status, expense, busy, message];
}

/// Loads one expense and runs its actions: post, cancel, void and managing
/// receipts.
class ExpenseDetailCubit extends Cubit<ExpenseDetailState> {
  /// Creates the cubit.
  ExpenseDetailCubit({
    required ExpenseRepository expenses,
    required PostExpense post,
    required CancelExpense cancel,
    required VoidExpense voidExpense,
    required AddExpenseAttachment addAttachment,
    required RemoveExpenseAttachment removeAttachment,
  }) : _expenses = expenses,
       _post = post,
       _cancel = cancel,
       _void = voidExpense,
       _addAttachment = addAttachment,
       _removeAttachment = removeAttachment,
       super(const ExpenseDetailState());

  final ExpenseRepository _expenses;
  final PostExpense _post;
  final CancelExpense _cancel;
  final VoidExpense _void;
  final AddExpenseAttachment _addAttachment;
  final RemoveExpenseAttachment _removeAttachment;
  String? _id;

  /// Loads expense [id]; unknown ids end in [DetailStatus.notFound].
  Future<void> load(String id) async {
    _id = id;
    emit(const ExpenseDetailState());
    final result = await _expenses.getById(id);
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(
        ExpenseDetailState(
          status: failure is NotFoundFailure
              ? DetailStatus.notFound
              : DetailStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    emit(
      ExpenseDetailState(
        status: DetailStatus.loaded,
        expense: result.valueOrNull,
      ),
    );
  }

  /// Posts the draft so it counts in the reports.
  Future<void> post() => _run(() => _post(_requireId), 'Posted');

  /// Cancels the draft.
  Future<void> cancel() => _run(() => _cancel(_requireId), 'Cancelled');

  /// Voids the posted expense.
  Future<void> voidExpense(String reason) =>
      _run(() => _void(_requireId, reason: reason), 'Voided');

  /// Attaches the file at [path].
  Future<void> attach(String path) =>
      _run(() => _addAttachment(_requireId, path), 'File attached');

  /// Removes an attachment of a draft.
  Future<void> removeAttachment(String attachmentId) => _run(
    () => _removeAttachment(_requireId, attachmentId),
    'Attachment removed',
  );

  String get _requireId => _id!;

  Future<void> _run(
    Future<Result<Expense>> Function() action,
    String successMessage,
  ) async {
    if (_id == null || state.busy) {
      return;
    }
    emit(state.copyWith(busy: true));
    final result = await action();
    if (isClosed) {
      return;
    }
    result.when(
      success: (expense) => emit(
        state.copyWith(
          expense: expense,
          busy: false,
          message: '$successMessage.',
        ),
      ),
      failure: (failure) =>
          emit(state.copyWith(busy: false, message: failure.userMessage)),
    );
  }
}
