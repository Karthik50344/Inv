import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_form_cubit.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/features/sales/presentation/widgets/sales_line_sheet.dart';
import 'package:inventrix/features/sales/presentation/widgets/sales_totals_card.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Create or edit a sale draft. Pops with `true` after saving.
class SalesFormPage extends StatefulWidget {
  /// Creates the page. Provide a [SalesFormCubit] above it.
  const SalesFormPage({this.saleId, super.key});

  /// Draft being edited, or `null` for a new sale.
  final String? saleId;

  @override
  State<SalesFormPage> createState() => _SalesFormPageState();
}

class _SalesFormPageState extends State<SalesFormPage> {
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _textLoaded = false;

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    BuildContext context, {
    required DateTime? current,
    required void Function(DateTime) onPicked,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  Future<void> _editLine(
    BuildContext context,
    SalesFormCubit cubit,
    SalesFormState state, {
    int? index,
  }) async {
    final currency = state.currency;
    if (currency == null) {
      return;
    }
    await showSalesLineSheet(
      context,
      products: state.products,
      units: state.units,
      currency: currency,
      initial: index == null ? null : state.lines[index],
      onSave: (input) => cubit.saveLine(input, index: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesFormCubit, SalesFormState>(
      listenWhen: (previous, current) =>
          previous.submitStatus != current.submitStatus ||
          previous.loadStatus != current.loadStatus ||
          (current.message != null && current.message != previous.message),
      listener: (context, state) {
        if (state.loadStatus == FormLoadStatus.ready && !_textLoaded) {
          _textLoaded = true;
          _reference.text = state.customerReference;
          _notes.text = state.notes;
        }
        if (state.submitStatus == SubmitStatus.success) {
          context.pop(true);
          return;
        }
        if (state.message != null && state.loadStatus == FormLoadStatus.ready) {
          showAppMessage(context, state.message!);
        }
      },
      builder: (context, state) {
        final cubit = context.read<SalesFormCubit>();
        return Scaffold(
          appBar: AppAppBar(
            title: widget.saleId == null ? 'New sale' : 'Edit sale',
          ),
          body: switch (state.loadStatus) {
            FormLoadStatus.loading => const LoadingIndicator(),
            FormLoadStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Sale not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            FormLoadStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the form.',
              onRetry: () => cubit.load(saleId: widget.saleId),
            ),
            FormLoadStatus.ready => _form(context, cubit, state),
          },
        );
      },
    );
  }

  Widget _form(
    BuildContext context,
    SalesFormCubit cubit,
    SalesFormState state,
  ) {
    const formatter = MoneyFormatter();
    final errors = state.fieldErrors;
    final blocked = state.blockedReason;
    final saving = state.submitStatus == SubmitStatus.submitting;
    final theme = Theme.of(context);
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: child,
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppDimensions.maxContentWidth,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          children: [
            if (blocked != null)
              gap(
                AppCard(
                  tone: AppTone.danger,
                  child: Text(
                    blocked,
                    key: const Key('sales_blocked'),
                    style: TextStyle(
                      color: context.appColors.danger.onContainer,
                    ),
                  ),
                ),
              ),
            const AppSectionHeader(
              title: 'Customer and dates',
              padding: EdgeInsets.only(bottom: AppSpacing.s12),
            ),
            gap(
              DropdownButtonFormField<String>(
                key: const Key('sales_customer'),
                initialValue: state.customerId ?? '',
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Customer',
                  errorText: errors['customerId'],
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Walk-in customer'),
                  ),
                  for (final s in state.customers)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: blocked == null
                    ? (value) => cubit.setCustomer(
                        value == null || value.isEmpty ? null : value,
                      )
                    : null,
              ),
            ),
            gap(
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      fieldKey: const Key('sales_date'),
                      label: 'Invoice date *',
                      value: state.invoiceDate,
                      error: errors['invoiceDate'],
                      onTap: blocked != null
                          ? null
                          : () => _pickDate(
                              context,
                              current: state.invoiceDate,
                              onPicked: cubit.setInvoiceDate,
                            ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: _DateField(
                      fieldKey: const Key('sales_due_date'),
                      label: 'Due date',
                      value: state.dueDate,
                      error: errors['dueDate'],
                      onClear: state.dueDate == null || blocked != null
                          ? null
                          : () => cubit.setDueDate(null),
                      onTap: blocked != null
                          ? null
                          : () => _pickDate(
                              context,
                              current: state.dueDate ?? state.invoiceDate,
                              onPicked: cubit.setDueDate,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            gap(
              TextField(
                key: const Key('sales_reference'),
                controller: _reference,
                enabled: blocked == null,
                decoration: InputDecoration(
                  labelText: 'Customer reference',
                  errorText: errors['customerReference'],
                ),
              ),
            ),
            gap(
              TextField(
                key: const Key('sales_notes'),
                controller: _notes,
                enabled: blocked == null,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notes',
                  errorText: errors['notes'],
                ),
              ),
            ),
            AppSectionHeader(
              title: 'Items',
              padding: const EdgeInsets.only(
                top: AppSpacing.s8,
                bottom: AppSpacing.s8,
              ),
              trailing: AppButton(
                key: const Key('add_line'),
                label: 'Add item',
                icon: Icons.add,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.small,
                onPressed: blocked == null
                    ? () => _editLine(context, cubit, state)
                    : null,
              ),
            ),
            if (errors['lines'] != null)
              gap(
                Text(
                  errors['lines']!,
                  key: const Key('lines_error'),
                  style: TextStyle(color: context.appColors.danger.solid),
                ),
              ),
            if (state.lines.isEmpty && errors['lines'] == null)
              gap(
                Text(
                  'No items yet. Tap "Add item" to choose a product.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
            for (var i = 0; i < state.lines.length; i++)
              _lineCard(context, cubit, state, i, formatter, blocked == null),
            const SizedBox(height: AppSpacing.s8),
            if (state.totals != null) SalesTotalsCard(totals: state.totals!),
            const SizedBox(height: AppSpacing.s16),
            AppButton(
              key: const Key('save_sale'),
              label: 'Save draft',
              icon: Icons.check,
              expand: true,
              loading: saving,
              onPressed: blocked != null
                  ? null
                  : () => cubit.submit(
                      customerReference: _reference.text,
                      notes: _notes.text,
                    ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              'A draft does not change your stock. Post it from the sale '
              'screen when the goods are handed over.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(
    BuildContext context,
    SalesFormCubit cubit,
    SalesFormState state,
    int index,
    MoneyFormatter formatter,
    bool enabled,
  ) {
    final input = state.lines[index];
    final preview = index < state.previews.length
        ? state.previews[index]
        : null;
    final product = state.products
        .where((p) => p.id == input.productId)
        .firstOrNull;
    final unit =
        preview?.unitSymbol ?? state.units[product?.unitId]?.symbol ?? '';
    final lineErrors = [
      for (final key in ['product', 'quantity', 'unitPrice', 'discount'])
        if (state.fieldErrors['lines.$index.$key'] != null)
          state.fieldErrors['lines.$index.$key']!,
    ];
    final theme = Theme.of(context);
    final tokens = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: AppCard(
        key: Key('line_$index'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s12,
          AppSpacing.s4,
          AppSpacing.s12,
        ),
        onTap: enabled
            ? () => _editLine(context, cubit, state, index: index)
            : null,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview?.productName ?? product?.name ?? 'Unknown product',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      '${input.quantity} $unit'.trim(),
                      if (preview != null)
                        '× ${formatter.format(preview.unitPrice)}'
                            '${preview.priceIncludesTax ? ' (incl. tax)' : ''}',
                      if (preview != null && preview.discountAmount.isPositive)
                        'discount ${formatter.format(preview.discountAmount)}',
                      if (preview != null && preview.taxRateBp > 0)
                        '${preview.taxName ?? 'Tax'} ${formatter.format(preview.tax)}',
                      ...lineErrors,
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: lineErrors.isEmpty
                          ? tokens.textSecondary
                          : tokens.danger.solid,
                    ),
                  ),
                ],
              ),
            ),
            if (preview != null) ...[
              AppSpacing.hGap8,
              Text(
                formatter.format(preview.total),
                key: Key('line_total_$index'),
                style: context.appText.financialSmall,
              ),
            ],
            AppIconButton(
              key: Key('remove_line_$index'),
              tooltip: 'Remove',
              icon: Icons.delete_outline,
              onPressed: enabled ? () => cubit.removeLine(index) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onTap,
    this.error,
    this.onClear,
  });

  final Key fieldKey;
  final String label;
  final DateTime? value;
  final String? error;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: fieldKey,
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          suffixIcon: onClear == null
              ? const Icon(Icons.calendar_today_outlined, size: 18)
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                ),
        ),
        child: Text(value == null ? '—' : formatDocumentDate(value!)),
      ),
    );
  }
}
