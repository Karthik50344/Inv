import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_form_cubit.dart';
import 'package:inventrix/features/expenses/presentation/widgets/expense_formatters.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

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

  Future<void> _pickDate(
    BuildContext context,
    ExpenseFormCubit cubit,
    DateTime? current,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      cubit.setDate(picked);
    }
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
          appBar: AppBar(
            title: Text(
              widget.expenseId == null ? 'New expense' : 'Edit expense',
            ),
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
    final taxApplies =
        state.taxRateId != null &&
        state.taxRates.any((t) => t.id == state.taxRateId && !t.isExempt);
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      child: child,
    );
    final preview = state.preview;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.maxContentWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.spaceMd),
          children: [
            if (blocked != null)
              gap(
                Text(
                  blocked,
                  key: const Key('expense_blocked'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            gap(
              TextField(
                key: const Key('expense_description'),
                controller: _description,
                enabled: blocked == null,
                decoration: InputDecoration(
                  labelText: 'What was it for? *',
                  errorText: errors['description'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            gap(
              DropdownButtonFormField<String>(
                key: const Key('expense_category'),
                initialValue: state.categoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Category *',
                  errorText: errors['categoryId'],
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final c in state.categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: blocked == null ? cubit.setCategory : null,
              ),
            ),
            gap(
              InkWell(
                key: const Key('expense_date'),
                onTap: blocked != null
                    ? null
                    : () => _pickDate(context, cubit, state.expenseDate),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date *',
                    errorText: errors['expenseDate'],
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                    ),
                  ),
                  child: Text(
                    state.expenseDate == null
                        ? '—'
                        : formatExpenseDate(state.expenseDate!),
                  ),
                ),
              ),
            ),
            gap(
              TextField(
                key: const Key('expense_amount'),
                controller: _amount,
                enabled: blocked == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: cubit.setAmount,
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  prefixText: '${state.currency?.currencyCode ?? ''} ',
                  errorText: errors['amount'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            gap(
              DropdownButtonFormField<String?>(
                key: const Key('expense_tax'),
                initialValue: state.taxRateId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Tax',
                  errorText: errors['taxRateId'],
                  border: const OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String?>(child: Text('No tax')),
                  for (final t in state.taxRates)
                    DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
                ],
                onChanged: blocked == null ? cubit.setTaxRate : null,
              ),
            ),
            if (taxApplies)
              gap(
                SwitchListTile(
                  key: const Key('expense_includes_tax'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Amount includes tax'),
                  value: state.amountIncludesTax,
                  onChanged: blocked == null
                      ? (value) => cubit.setIncludesTax(value: value)
                      : null,
                ),
              ),
            if (preview != null)
              gap(
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.spaceMd),
                    child: Column(
                      children: [
                        _row(theme, 'Net', formatter.format(preview.net)),
                        _row(theme, 'Tax', formatter.format(preview.tax)),
                        const Divider(),
                        _row(
                          theme,
                          'Total',
                          formatter.format(preview.total),
                          strong: true,
                          key: const Key('expense_total'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            gap(
              DropdownButtonFormField<String>(
                key: const Key('expense_method'),
                initialValue: state.methodId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Paid with *',
                  errorText: errors['methodId'],
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final m in state.methods)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: blocked == null ? cubit.setMethod : null,
              ),
            ),
            gap(
              TextField(
                key: const Key('expense_payee'),
                controller: _payee,
                enabled: blocked == null,
                decoration: InputDecoration(
                  labelText: 'Paid to',
                  errorText: errors['payee'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            gap(
              TextField(
                key: const Key('expense_reference'),
                controller: _reference,
                enabled: blocked == null,
                decoration: InputDecoration(
                  labelText: 'Receipt or reference no.',
                  errorText: errors['reference'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            gap(
              TextField(
                key: const Key('expense_notes'),
                controller: _notes,
                enabled: blocked == null,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  errorText: errors['notes'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            FilledButton(
              key: const Key('save_and_post_expense'),
              onPressed: (saving || blocked != null)
                  ? null
                  : () => _submit(cubit, post: true),
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save and post'),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            OutlinedButton(
              key: const Key('save_expense_draft'),
              onPressed: (saving || blocked != null)
                  ? null
                  : () => _submit(cubit, post: false),
              child: const Text('Save as draft'),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              'Only posted expenses count in reports. A posted expense '
              'cannot be edited; it can be voided with a reason. You can '
              'attach receipts after saving.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
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
}
