import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_attachment.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_attachments.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_detail_cubit.dart';
import 'package:inventrix/features/expenses/presentation/widgets/expense_formatters.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/document_status_chip.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/void_reason_dialog.dart';

/// An expense with its actions: edit, post, cancel, void and receipts.
class ExpenseDetailPage extends StatelessWidget {
  /// Creates the page. Provide an [ExpenseDetailCubit] above it.
  const ExpenseDetailPage({required this.expenseId, super.key});

  /// Id of the expense to show.
  final String expenseId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseDetailCubit, ExpenseDetailState>(
      listenWhen: (previous, current) =>
          current.message != null &&
          current.status == DetailStatus.loaded &&
          current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<ExpenseDetailCubit>();
        final expense = state.expense;
        return Scaffold(
          appBar: AppBar(
            title: Text(expense?.displayNumber ?? 'Expense'),
            actions: [
              if (expense != null && expense.isEditable)
                IconButton(
                  key: const Key('edit_expense'),
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: state.busy
                      ? null
                      : () async {
                          await context.pushNamed(
                            RouteNames.expenseEdit,
                            pathParameters: {'id': expense.id},
                          );
                          await cubit.load(expense.id);
                        },
                ),
            ],
          ),
          body: switch (state.status) {
            DetailStatus.loading => const LoadingIndicator(),
            DetailStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Expense not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            DetailStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the expense.',
              onRetry: () => cubit.load(expenseId),
            ),
            DetailStatus.loaded => _Details(state: state),
          },
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.state});

  final ExpenseDetailState state;

  Future<void> _attach(BuildContext context) async {
    final cubit = context.read<ExpenseDetailCubit>();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    final path = result?.files.single.path;
    if (path != null) {
      await cubit.attach(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = state.expense!;
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    Widget row(String label, String? value, {Key? key}) => ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value ?? '—', key: key),
    );
    final canAttach =
        (expense.status == DocumentStatus.draft ||
            expense.status == DocumentStatus.posted) &&
        expense.attachments.length < AddExpenseAttachment.maxAttachments;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.maxContentWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: DocumentStatusChip(status: expense.status),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spaceSm,
              ),
              child: Text(
                expense.description,
                key: const Key('expense_detail_description'),
                style: theme.textTheme.titleLarge,
              ),
            ),
            row('Category', expense.categoryName),
            row('Date', formatExpenseDate(expense.expenseDate)),
            row('Paid with', expense.methodName),
            if (expense.payee != null) row('Paid to', expense.payee),
            if (expense.reference != null) row('Reference', expense.reference),
            if (expense.status == DocumentStatus.voided) ...[
              row(
                'Voided',
                expense.voidedAt == null
                    ? null
                    : formatExpenseDate(expense.voidedAt!),
              ),
              row('Reason', expense.voidReason, key: const Key('void_reason')),
            ],
            if (expense.notes != null)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spaceSm),
                child: Text(expense.notes!),
              ),
            const SizedBox(height: AppDimensions.spaceSm),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                child: Column(
                  children: [
                    _amountRow(
                      theme,
                      'Net',
                      formatter.format(expense.amounts.net),
                    ),
                    _amountRow(
                      theme,
                      expense.taxName ?? 'Tax',
                      formatter.format(expense.amounts.tax),
                    ),
                    const Divider(),
                    _amountRow(
                      theme,
                      'Total',
                      formatter.format(expense.amounts.total),
                      strong: true,
                      key: const Key('expense_detail_total'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Row(
              children: [
                Expanded(
                  child: Text('Receipts', style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  key: const Key('add_attachment'),
                  onPressed: canAttach && !state.busy
                      ? () => _attach(context)
                      : null,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach'),
                ),
              ],
            ),
            if (expense.attachments.isEmpty)
              Text(
                'No receipts attached.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            for (final attachment in expense.attachments)
              _AttachmentTile(
                attachment: attachment,
                canRemove: expense.isEditable && !state.busy,
              ),
            const SizedBox(height: AppDimensions.spaceMd),
            ..._actions(context, expense.status),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
    ThemeData theme,
    String label,
    String value, {
    bool strong = false,
    Key? key,
  }) {
    final style = strong
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, key: key, style: style),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, DocumentStatus status) {
    final cubit = context.read<ExpenseDetailCubit>();
    final busy = state.busy;
    const gap = SizedBox(height: AppDimensions.spaceSm);
    switch (status) {
      case DocumentStatus.draft:
        return [
          FilledButton(
            key: const Key('post_expense'),
            onPressed: busy
                ? null
                : () async {
                    final confirmed = await showConfirmationDialog(
                      context,
                      title: 'Post this expense?',
                      message:
                          'It will get a number and count in your reports. '
                          'A posted expense cannot be edited, only voided.',
                      confirmLabel: 'Post',
                    );
                    if (confirmed) {
                      await cubit.post();
                    }
                  },
            child: const Text('Post expense'),
          ),
          gap,
          OutlinedButton(
            key: const Key('cancel_expense'),
            onPressed: busy
                ? null
                : () async {
                    final confirmed = await showConfirmationDialog(
                      context,
                      title: 'Cancel this draft?',
                      message:
                          'The draft is kept under "Cancelled" and will not '
                          'count in reports.',
                      confirmLabel: 'Cancel draft',
                      cancelLabel: 'Keep',
                      destructive: true,
                    );
                    if (confirmed) {
                      await cubit.cancel();
                    }
                  },
            child: const Text('Cancel draft'),
          ),
        ];
      case DocumentStatus.posted:
        return [
          OutlinedButton(
            key: const Key('void_expense'),
            onPressed: busy
                ? null
                : () async {
                    final reason = await askVoidReason(
                      context,
                      title: 'Void this expense?',
                    );
                    if (reason != null) {
                      await cubit.voidExpense(reason);
                    }
                  },
            child: const Text('Void expense'),
          ),
        ];
      case _:
        return const [];
    }
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.attachment, required this.canRemove});

  final ExpenseAttachment attachment;
  final bool canRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('attachment_${attachment.id}'),
      child: ListTile(
        leading: Icon(
          attachment.isImage
              ? Icons.image_outlined
              : Icons.picture_as_pdf_outlined,
        ),
        title: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
        subtitle: Text(_describe(attachment)),
        trailing: canRemove
            ? IconButton(
                key: Key('remove_attachment_${attachment.id}'),
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final cubit = context.read<ExpenseDetailCubit>();
                  final confirmed = await showConfirmationDialog(
                    context,
                    title: 'Remove attachment?',
                    message: 'The file will be deleted from this device.',
                    confirmLabel: 'Remove',
                    destructive: true,
                  );
                  if (confirmed) {
                    await cubit.removeAttachment(attachment.id);
                  }
                },
              )
            : null,
      ),
    );
  }
}

String _describe(ExpenseAttachment attachment) =>
    '${formatFileSize(attachment.sizeBytes)} · '
    '${formatExpenseDate(attachment.createdAt)}';
