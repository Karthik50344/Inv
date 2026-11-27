import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/returns/domain/entities/returnable_invoice.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_form_cubit.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Records a return: choose a posted invoice, enter what comes back, see the
/// value and the possible cash refund, then post.
class ReturnFormPage extends StatelessWidget {
  /// Creates the page. Provide a [ReturnFormCubit] above it.
  const ReturnFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReturnFormCubit, ReturnFormState>(
      listenWhen: (previous, current) =>
          (current.message != null && current.message != previous.message) ||
          (current.submitStatus == SubmitStatus.success &&
              previous.submitStatus != SubmitStatus.success),
      listener: (context, state) {
        if (state.submitStatus == SubmitStatus.success) {
          showAppMessage(context, 'Return posted.');
          context.pop();
          return;
        }
        if (state.message != null) {
          showAppMessage(context, state.message!);
        }
      },
      builder: (context, state) {
        final cubit = context.read<ReturnFormCubit>();
        final invoice = state.invoice;
        return Scaffold(
          appBar: AppAppBar(
            title: invoice == null
                ? (state.kind == InvoiceKind.sales
                      ? 'Customer return'
                      : 'Return to supplier')
                : 'Return against ${invoice.invoiceNumber}',
          ),
          body: AppContentWidth(child: switch (state.loadStatus) {
            FormLoadStatus.loading => const LoadingIndicator(),
            FormLoadStatus.failure || FormLoadStatus.notFound => ErrorState(
              message: state.message ?? 'Could not open the form.',
              onRetry: cubit.load,
            ),
            FormLoadStatus.ready =>
              invoice == null
                  ? _Chooser(state: state)
                  : _Editor(state: state, invoice: invoice),
          }),
        );
      },
    );
  }
}

class _Chooser extends StatelessWidget {
  const _Chooser({required this.state});

  final ReturnFormState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReturnFormCubit>();
    const formatter = MoneyFormatter();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s8,
            AppSpacing.s16,
            0,
          ),
          child: SegmentedButton<InvoiceKind>(
            key: const Key('return_kind'),
            segments: const [
              ButtonSegment(
                value: InvoiceKind.sales,
                label: Text('Sales'),
                icon: Icon(Icons.sell_outlined),
              ),
              ButtonSegment(
                value: InvoiceKind.purchase,
                label: Text('Purchases'),
                icon: Icon(Icons.shopping_cart_outlined),
              ),
            ],
            selected: {state.kind},
            onSelectionChanged: (value) => cubit.setKind(value.first),
          ),
        ),
        AppSearchField(
          hintText: 'Search invoice number or name',
          onChanged: cubit.searchInvoices,
        ),
        Expanded(
          child: state.choices.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No posted invoices found',
                  message: 'Only posted invoices can have returns.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    AppSpacing.s4,
                    AppSpacing.s16,
                    AppSpacing.s24,
                  ),
                  itemCount: state.choices.length,
                  separatorBuilder: (_, _) => AppSpacing.gap8,
                  itemBuilder: (context, index) {
                    final choice = state.choices[index];
                    final theme = Theme.of(context);
                    return AppCard(
                      key: Key('choice_${choice.id}'),
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      onTap: () => cubit.selectInvoice(choice.id),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${choice.number} · ${choice.partyName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatDocumentDate(choice.invoiceDate),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: context.appColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AppSpacing.hGap8,
                          Text(
                            formatter.format(choice.total),
                            style: context.appText.financialSmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.state, required this.invoice});

  final ReturnFormState state;
  final ReturnableInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReturnFormCubit>();
    final theme = Theme.of(context);
    const formatter = MoneyFormatter();
    final plan = state.plan;
    final isSales = invoice.kind == InvoiceKind.sales;
    final submitting = state.submitStatus == SubmitStatus.submitting;
    final total = plan?.total ?? invoice.zero;
    final max = state.maxRefund ?? invoice.zero;
    final errors = state.fieldErrors;

    final tokens = context.appColors;
    return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: AppSpacing.page,
      children: [
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.partyName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${invoice.invoiceNumber} · '
                      '${formatDocumentDate(invoice.invoiceDate)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppButton(
                key: const Key('change_invoice'),
                label: 'Change',
                variant: AppButtonVariant.text,
                size: AppButtonSize.small,
                onPressed: cubit.clearInvoice,
              ),
            ],
          ),
        ),
        AppSectionHeader(
          title: 'Items',
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s16,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
          trailing: AppButton(
            key: const Key('return_everything'),
            label: 'Return everything',
            variant: AppButtonVariant.text,
            size: AppButtonSize.small,
            onPressed: invoice.hasReturnable ? cubit.returnEverything : null,
          ),
        ),
        for (final line in invoice.lines)
          _LineCard(
            line: line,
            isSales: isSales,
            quantity: state.quantities[line.invoiceLineId] ?? '',
            restock: state.restock[line.invoiceLineId] ?? true,
            error:
                plan?.lineErrors[line.invoiceLineId] ??
                errors['line:${line.invoiceLineId}'],
          ),
        const AppSectionHeader(
          title: 'Return details',
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s16,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
        ),
        AppTextField(
          key: const Key('return_reason'),
          label: 'Reason',
          errorText: errors['reason'],
          textCapitalization: TextCapitalization.sentences,
          onChanged: cubit.setReason,
        ),
        AppSpacing.gap12,
        AppTextField(
          key: const Key('return_notes'),
          label: 'Notes (optional)',
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          minLines: 1,
          onChanged: cubit.setNotes,
        ),
        AppSpacing.gap12,
        AppDatePickerField(
          key: const Key('return_date'),
          label: 'Return date',
          value: state.returnDate,
          errorText: errors['returnDate'],
          onChanged: cubit.setDate,
        ),
        AppSpacing.gap16,
        AppCard(
          child: Row(
            key: const Key('return_value'),
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Value of this return',
                      style: theme.textTheme.titleMedium,
                    ),
                    if (plan != null && plan.tax.isPositive)
                      Text(
                        'including tax ${formatter.format(plan.tax)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              AppSpacing.hGap8,
              Text(
                formatter.format(total),
                style: context.appText.financialMedium,
              ),
            ],
          ),
        ),
        AppSpacing.gap12,
        _Settlement(
          state: state,
          invoice: invoice,
          total: total,
          max: max,
          isSales: isSales,
          errors: errors,
        ),
        AppSpacing.gap16,
        AppButton(
          key: const Key('post_return'),
          label: submitting ? 'Posting...' : 'Post return',
          icon: Icons.check,
          expand: true,
          loading: submitting,
          onPressed: submitting || plan == null || !plan.isValid
              ? null
              : () => cubit.submit(),
        ),
      ],
    );
  }
}

class _Settlement extends StatelessWidget {
  const _Settlement({
    required this.state,
    required this.invoice,
    required this.total,
    required this.max,
    required this.isSales,
    required this.errors,
  });

  final ReturnFormState state;
  final ReturnableInvoice invoice;
  final Money total;
  final Money max;
  final bool isSales;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReturnFormCubit>();
    const formatter = MoneyFormatter();
    final canRefund = invoice.isWalkIn || max.isPositive;
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final String explanation;
    if (invoice.isWalkIn) {
      explanation =
          'This was a walk-in sale, so the whole value '
          '(${formatter.format(total)}) is handed back.';
    } else if (!canRefund) {
      explanation = isSales
          ? 'The value of this return is taken off what the customer '
                'owes. Nothing has been paid beyond that, so there is '
                'nothing to refund in cash.'
          : 'The value of this return is taken off what you owe the '
                'supplier. Nothing has been paid beyond that, so '
                'there is nothing to claim back in cash.';
    } else {
      explanation = isSales
          ? 'Cash to hand back to the customer (up to '
                '${formatter.format(max)}). Whatever you '
                'do not hand back stays as credit.'
          : 'Cash the supplier hands back (up to '
                '${formatter.format(max)}). The rest stays '
                'as credit.';
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settlement', style: theme.textTheme.titleMedium),
          AppSpacing.gap4,
          Text(
            explanation,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tokens.textSecondary,
            ),
          ),
          if (!invoice.isWalkIn && canRefund) ...[
            AppSpacing.gap12,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SyncedField(
                    key: const Key('refund_amount'),
                    value: state.refundText,
                    labelText: 'Cash refund',
                    errorText: errors['refund'],
                    onChanged: cubit.setRefundText,
                  ),
                ),
                AppSpacing.hGap8,
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s4),
                  child: AppButton(
                    key: const Key('refund_maximum'),
                    label: 'Maximum',
                    variant: AppButtonVariant.secondary,
                    size: AppButtonSize.small,
                    onPressed: cubit.refundMaximum,
                  ),
                ),
              ],
            ),
          ],
          if (invoice.isWalkIn || state.refundText.trim().isNotEmpty) ...[
            AppSpacing.gap12,
            AppDropdown<String>(
              key: const Key('refund_method'),
              label: 'Paid back by',
              value: state.refundMethodId,
              items: [
                for (final method in state.methods)
                  AppDropdownItem(value: method.id, label: method.name),
              ],
              onChanged: cubit.setRefundMethod,
            ),
            if (errors['refundMethod'] != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s4),
                child: Text(
                  errors['refundMethod']!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            AppSpacing.gap12,
            AppTextField(
              key: const Key('refund_reference'),
              label: 'Reference (optional)',
              onChanged: cubit.setRefundReference,
            ),
          ],
        ],
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  const _LineCard({
    required this.line,
    required this.isSales,
    required this.quantity,
    required this.restock,
    required this.error,
  });

  final ReturnableLine line;
  final bool isSales;
  final String quantity;
  final bool restock;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ReturnFormCubit>();
    final theme = Theme.of(context);
    final left = line.returnable;
    final tokens = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: AppCard(
        key: Key('return_line_${line.lineNo}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${line.productName} (${line.sku})',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 2),
            Text(
              'Invoiced ${line.quantity.toDecimalString()} ${line.unitSymbol}'
              '${line.returnedQuantity.isPositive ? ' · already returned ${line.returnedQuantity.toDecimalString()}' : ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            if (left.isPositive) ...[
              AppSpacing.gap12,
              _SyncedField(
                key: Key('return_qty_${line.invoiceLineId}'),
                value: quantity,
                labelText: 'Quantity to return (max '
                    '${left.toDecimalString()} ${line.unitSymbol})',
                errorText: error,
                onChanged: (text) => cubit.setQuantity(line.invoiceLineId, text),
              ),
              if (isSales)
                SwitchListTile(
                  key: Key('return_restock_${line.invoiceLineId}'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Put back in stock'),
                  subtitle: const Text('Turn off for damaged goods.'),
                  value: restock,
                  onChanged: (value) => cubit.setRestock(
                    line.invoiceLineId,
                    restock: value,
                  ),
                ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s8),
                child: const AppBadge(
                  label: 'Fully returned',
                  tone: AppTone.success,
                  icon: Icons.check,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A numeric text field whose text follows [value] when it is changed from
/// outside (for example by "Return everything" or "Maximum") and keeps the
/// cursor and focus while the user types.
class _SyncedField extends StatefulWidget {
  const _SyncedField({
    required this.value,
    required this.labelText,
    required this.onChanged,
    this.errorText,
    super.key,
  });

  final String value;
  final String labelText;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  State<_SyncedField> createState() => _SyncedFieldState();
}

class _SyncedFieldState extends State<_SyncedField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_SyncedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.labelText,
        errorText: widget.errorText,
      ),
      onChanged: widget.onChanged,
    );
  }
}
