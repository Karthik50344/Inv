import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_form_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Create or edit an expense draft, optionally posting it right away. Pops
/// with `true` after saving.
class ExpenseFormPage extends StatefulWidget {
  /// Creates the page. Provide an [ExpenseFormCubit] above it.
  const ExpenseFormPage({this.expenseId, super.key});

  /// Draft being edited, or `null` for a new expense.
  final String? expenseId;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _description = TextEditingController();
  final _payee = TextEditingController();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _textLoaded = false;

  @override
  void dispose() {
    _description.dispose();
    _payee.dispose();
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit(ExpenseFormCubit cubit, {required bool post}) => cubit.submit(
    description: _description.text,
    payee: _payee.text,
    reference: _reference.text,
    notes: _notes.text,
    post: post,
  );

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseFormCubit, ExpenseFormState>(
      listenWhen: (previous, current) =>
          previous.submitStatus != current.submitStatus ||
          previous.loadStatus != current.loadStatus ||
          (current.message != null && current.message != previous.message),
      listener: (context, state) {
        if (state.loadStatus == FormLoadStatus.ready && !_textLoaded) {
          _textLoaded = true;
          _description.text = state.description;
          _payee.text = state.payee;
          _amount.text = state.amount;
          _reference.text = state.reference;
          _notes.text = state.notes;
        }
        if (state.submitStatus == SubmitStatus.success) {
          if (state.message != null) {
            showAppMessage(context, state.message!);
          }
          context.pop(true);
          return;
        }
        if (state.message != null && state.loadStatus == FormLoadStatus.ready) {
          showAppMessage(context, state.message!);
        }
      },
      builder: (context, state) {
        final cubit = context.read<ExpenseFormCubit>();
        return Scaffold(
          appBar: AppAppBar(
            title: widget.expenseId == null ? 'New expense' : 'Edit expense',
          ),
          body: switch (state.loadStatus) {
            FormLoadStatus.loading => const LoadingIndicator(),
            FormLoadStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Expense not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            FormLoadStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the form.',
              onRetry: () => cubit.load(expenseId: widget.expenseId),
            ),
            FormLoadStatus.ready => _form(context, cubit, state),
          },
        );
      },
    );
  }

  Widget _form(
    BuildContext context,
    ExpenseFormCubit cubit,
    ExpenseFormState state,
  ) {
    const formatter = MoneyFormatter();
    final errors = state.fieldErrors;
    final blocked = state.blockedReason;
    final saving = state.submitStatus == SubmitStatus.submitting;
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final now = DateTime.now();
    final taxApplies =
        state.taxRateId != null &&
        state.taxRates.any((t) => t.id == state.taxRateId && !t.isExempt);
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: child,
    );
    Widget totalRow(
      String label,
      String value, {
      bool strong = false,
      Key? key,
    }) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: strong
                ? theme.textTheme.titleMedium
                : theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
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
    final preview = state.preview;
    final enabled = blocked == null;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.maxContentWidth,
        ),
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: AppSpacing.page,
          children: [
            if (blocked != null)
              gap(
                AppCard(
                  tone: AppTone.danger,
                  child: Text(
                    blocked,
                    key: const Key('expense_blocked'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            const AppSectionHeader(
              title: 'Expense',
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s4,
                0,
                AppSpacing.s4,
                AppSpacing.s8,
              ),
            ),
            gap(
              AppTextField(
                key: const Key('expense_description'),
                controller: _description,
                enabled: enabled,
                label: 'What was it for? *',
                errorText: errors['description'],
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            gap(
              AppDropdown<String>(
                key: const Key('expense_category'),
                label: 'Category *',
                value: state.categoryId,
                errorText: errors['categoryId'],
                items: [
                  for (final c in state.categories)
                    AppDropdownItem(value: c.id, label: c.name),
                ],
                onChanged: enabled ? cubit.setCategory : null,
              ),
            ),
            gap(
              AppDatePickerField(
                key: const Key('expense_date'),
                label: 'Date *',
                value: state.expenseDate,
                first: DateTime(2000),
                last: DateTime(now.year + 1, 12, 31),
                errorText: errors['expenseDate'],
                enabled: enabled,
                onChanged: cubit.setDate,
              ),
            ),
            const AppSectionHeader(
              title: 'Amount',
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s8,
                AppSpacing.s4,
                AppSpacing.s8,
              ),
            ),
            gap(
              AppTextField(
                key: const Key('expense_amount'),
                controller: _amount,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: cubit.setAmount,
                label: 'Amount *',
                prefixText: '${state.currency?.currencyCode ?? ''} ',
                errorText: errors['amount'],
              ),
            ),
            gap(
              AppDropdown<String?>(
                key: const Key('expense_tax'),
                label: 'Tax',
                value: state.taxRateId,
                errorText: errors['taxRateId'],
                items: [
                  const AppDropdownItem<String?>(value: null, label: 'No tax'),
                  for (final t in state.taxRates)
                    AppDropdownItem<String?>(value: t.id, label: t.name),
                ],
                onChanged: enabled ? cubit.setTaxRate : null,
              ),
            ),
            if (taxApplies)
              gap(
                SwitchListTile(
                  key: const Key('expense_includes_tax'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Amount includes tax'),
                  value: state.amountIncludesTax,
                  onChanged: enabled
                      ? (value) => cubit.setIncludesTax(value: value)
                      : null,
                ),
              ),
            if (preview != null)
              gap(
                AppCard(
                  child: Column(
                    children: [
                      totalRow('Net', formatter.format(preview.net)),
                      totalRow('Tax', formatter.format(preview.tax)),
                      AppSpacing.gap8,
                      Divider(height: 1, color: tokens.divider),
                      AppSpacing.gap8,
                      totalRow(
                        'Total',
                        formatter.format(preview.total),
                        strong: true,
                        key: const Key('expense_total'),
                      ),
                    ],
                  ),
                ),
              ),
            const AppSectionHeader(
              title: 'Payment',
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s4,
                AppSpacing.s8,
                AppSpacing.s4,
                AppSpacing.s8,
              ),
            ),
            gap(
              AppDropdown<String>(
                key: const Key('expense_method'),
                label: 'Paid with *',
                value: state.methodId,
                errorText: errors['methodId'],
                items: [
                  for (final m in state.methods)
                    AppDropdownItem(value: m.id, label: m.name),
                ],
                onChanged: enabled ? cubit.setMethod : null,
              ),
            ),
            gap(
              AppTextField(
                key: const Key('expense_payee'),
                controller: _payee,
                enabled: enabled,
                label: 'Paid to',
                errorText: errors['payee'],
                textCapitalization: TextCapitalization.words,
              ),
            ),
            gap(
              AppTextField(
                key: const Key('expense_reference'),
                controller: _reference,
                enabled: enabled,
                label: 'Receipt or reference no.',
                errorText: errors['reference'],
              ),
            ),
            gap(
              AppTextField(
                key: const Key('expense_notes'),
                controller: _notes,
                enabled: enabled,
                minLines: 2,
                maxLines: 4,
                label: 'Notes',
                errorText: errors['notes'],
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            AppButton(
              key: const Key('save_and_post_expense'),
              label: 'Save and post',
              icon: Icons.check,
              expand: true,
              loading: saving,
              onPressed: (saving || blocked != null)
                  ? null
                  : () => _submit(cubit, post: true),
            ),
            AppSpacing.gap8,
            AppButton(
              key: const Key('save_expense_draft'),
              label: 'Save as draft',
              variant: AppButtonVariant.outlined,
              expand: true,
              onPressed: (saving || blocked != null)
                  ? null
                  : () => _submit(cubit, post: false),
            ),
            AppSpacing.gap12,
            Text(
              'Only posted expenses count in reports. A posted expense '
              'cannot be edited; it can be voided with a reason. You can '
              'attach receipts after saving.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
