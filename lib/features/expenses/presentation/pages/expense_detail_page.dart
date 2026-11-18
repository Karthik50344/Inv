import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_attachment.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_attachments.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_detail_cubit.dart';
import 'package:inventrix/features/expenses/presentation/widgets/expense_formatters.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';
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
          appBar: AppAppBar(
            title: expense?.displayNumber ?? 'Expense',
            actions: [
              if (expense != null && expense.isEditable)
                AppIconButton(
                  key: const Key('edit_expense'),
                  tooltip: 'Edit',
                  icon: Icons.edit_outlined,
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
    final tokens = context.appColors;
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
          padding: AppSpacing.page,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: DocumentStatusChip(status: expense.status),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
              child: Text(
                expense.description,
                key: const Key('expense_detail_description'),
                style: theme.textTheme.titleLarge,
              ),
            ),
            AppFactsCard(
              facts: [
                AppFact('Category', expense.categoryName),
                AppFact('Date', formatExpenseDate(expense.expenseDate)),
                AppFact('Paid with', expense.methodName),
                if (expense.payee != null) AppFact('Paid to', expense.payee),
                if (expense.reference != null)
                  AppFact('Reference', expense.reference),
                if (expense.status == DocumentStatus.voided) ...[
                  AppFact(
                    'Voided',
                    expense.voidedAt == null
                        ? null
                        : formatExpenseDate(expense.voidedAt!),
                  ),
                  AppFact(
                    'Reason',
                    expense.voidReason,
                    key: const Key('void_reason'),
                  ),
                ],
              ],
            ),
            if (expense.notes != null) ...[
              AppSpacing.gap12,
              AppCard(
                child: Text(
                  expense.notes!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
                ),
              ),
            ],
            AppSpacing.gap12,
            AppCard(
              child: Column(
                children: [
                  _amountRow(
                    context,
                    'Net',
                    formatter.format(expense.amounts.net),
                  ),
                  _amountRow(
                    context,
                    expense.taxName ?? 'Tax',
                    formatter.format(expense.amounts.tax),
                  ),
                  AppSpacing.gap8,
                  Divider(height: 1, color: tokens.divider),
                  AppSpacing.gap8,
                  _amountRow(
                    context,
                    'Total',
                    formatter.format(expense.amounts.total),
                    strong: true,
                    key: const Key('expense_detail_total'),
                  ),
                ],
              ),
            ),
            AppSectionHeader(
              title: 'Receipts',
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s24,
                AppSpacing.s4,
                AppSpacing.s8,
              ),
              trailing: AppButton(
                key: const Key('add_attachment'),
                label: 'Attach',
                icon: Icons.attach_file,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: canAttach && !state.busy
                    ? () => _attach(context)
                    : null,
              ),
            ),
            if (expense.attachments.isEmpty)
              Text(
                'No receipts attached.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
            for (final attachment in expense.attachments)
              _AttachmentTile(
                attachment: attachment,
                canRemove: expense.isEditable && !state.busy,
              ),
            AppSpacing.gap16,
            ..._actions(context, expense.status),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
    BuildContext context,
    String label,
    String value, {
    bool strong = false,
    Key? key,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: strong
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
          ),
          Text(
            value,
            key: key,
            style: strong
                ? context.appText.financialMedium
                : context.appText.financialSmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context, DocumentStatus status) {
    final cubit = context.read<ExpenseDetailCubit>();
    final busy = state.busy;
    const gap = AppSpacing.gap8;
    switch (status) {
      case DocumentStatus.draft:
        return [
          AppButton(
            key: const Key('post_expense'),
            label: 'Post expense',
            icon: Icons.check,
            expand: true,
            loading: busy,
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
          ),
          gap,
          AppButton(
            key: const Key('cancel_expense'),
            label: 'Cancel draft',
            variant: AppButtonVariant.outlined,
            expand: true,
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
          ),
        ];
      case DocumentStatus.posted:
        return [
          AppButton(
            key: const Key('void_expense'),
            label: 'Void expense',
            variant: AppButtonVariant.destructive,
            expand: true,
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
    final theme = Theme.of(context);
    final tokens = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: AppCard(
        key: Key('attachment_${attachment.id}'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s8,
          AppSpacing.s4,
          AppSpacing.s8,
        ),
        child: Row(
          children: [
            Icon(
              attachment.isImage
                  ? Icons.image_outlined
                  : Icons.picture_as_pdf_outlined,
              color: tokens.textSecondary,
            ),
            AppSpacing.hGap12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.fileName,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    _describe(attachment),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (canRemove)
              AppIconButton(
                key: Key('remove_attachment_${attachment.id}'),
                tooltip: 'Remove',
                icon: Icons.delete_outline,
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
              ),
          ],
        ),
      ),
    );
  }
}

String _describe(ExpenseAttachment attachment) =>
    '${formatFileSize(attachment.sizeBytes)} · '
    '${formatExpenseDate(attachment.createdAt)}';
