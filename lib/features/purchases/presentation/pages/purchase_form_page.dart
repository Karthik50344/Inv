import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_form_cubit.dart';
import 'package:inventrix/features/purchases/presentation/widgets/date_text.dart';
import 'package:inventrix/features/purchases/presentation/widgets/purchase_line_sheet.dart';
import 'package:inventrix/features/purchases/presentation/widgets/purchase_totals_card.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

/// Create or edit a purchase draft. Pops with `true` after saving.
class PurchaseFormPage extends StatefulWidget {
  /// Creates the page. Provide a [PurchaseFormCubit] above it.
  const PurchaseFormPage({this.purchaseId, super.key});

  /// Draft being edited, or `null` for a new purchase.
  final String? purchaseId;

  @override
  State<PurchaseFormPage> createState() => _PurchaseFormPageState();
}

class _PurchaseFormPageState extends State<PurchaseFormPage> {
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
    PurchaseFormCubit cubit,
    PurchaseFormState state, {
    int? index,
  }) async {
    final currency = state.currency;
    if (currency == null) {
      return;
    }
    await showPurchaseLineSheet(
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
    return BlocConsumer<PurchaseFormCubit, PurchaseFormState>(
      listenWhen: (previous, current) =>
          previous.submitStatus != current.submitStatus ||
          previous.loadStatus != current.loadStatus ||
          (current.message != null && current.message != previous.message),
      listener: (context, state) {
        if (state.loadStatus == FormLoadStatus.ready && !_textLoaded) {
          _textLoaded = true;
          _reference.text = state.supplierReference;
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
        final cubit = context.read<PurchaseFormCubit>();
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.purchaseId == null ? 'New purchase' : 'Edit purchase',
            ),
          ),
          body: switch (state.loadStatus) {
            FormLoadStatus.loading => const LoadingIndicator(),
            FormLoadStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Purchase not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            FormLoadStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the form.',
              onRetry: () => cubit.load(purchaseId: widget.purchaseId),
            ),
            FormLoadStatus.ready => _form(context, cubit, state),
          },
        );
      },
    );
  }

  Widget _form(
    BuildContext context,
    PurchaseFormCubit cubit,
    PurchaseFormState state,
  ) {
    const formatter = MoneyFormatter();
    final errors = state.fieldErrors;
    final blocked = state.blockedReason;
    final saving = state.submitStatus == SubmitStatus.submitting;
    final theme = Theme.of(context);
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
      child: child,
    );
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
                  key: const Key('purchase_blocked'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            gap(
              DropdownButtonFormField<String>(
                key: const Key('purchase_supplier'),
                initialValue: state.supplierId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Supplier *',
                  errorText: errors['supplierId'],
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final s in state.suppliers)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: blocked == null ? cubit.setSupplier : null,
              ),
            ),
            gap(
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      fieldKey: const Key('purchase_date'),
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
                  const SizedBox(width: AppDimensions.spaceMd),
                  Expanded(
                    child: _DateField(
                      fieldKey: const Key('purchase_due_date'),
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
                key: const Key('purchase_reference'),
                controller: _reference,
                enabled: blocked == null,
                decoration: InputDecoration(
                  labelText: 'Supplier invoice no.',
                  errorText: errors['supplierReference'],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            gap(
              TextField(
                key: const Key('purchase_notes'),
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
            Row(
              children: [
                Expanded(
                  child: Text('Items', style: theme.textTheme.titleMedium),
                ),
                TextButton.icon(
                  key: const Key('add_line'),
                  onPressed: blocked == null
                      ? () => _editLine(context, cubit, state)
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ],
            ),
            if (errors['lines'] != null)
              gap(
                Text(
                  errors['lines']!,
                  key: const Key('lines_error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (state.lines.isEmpty && errors['lines'] == null)
              gap(
                Text(
                  'No items yet. Tap "Add item" to choose a product.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (var i = 0; i < state.lines.length; i++)
              _lineCard(context, cubit, state, i, formatter, blocked == null),
            const SizedBox(height: AppDimensions.spaceSm),
            if (state.totals != null) PurchaseTotalsCard(totals: state.totals!),
            const SizedBox(height: AppDimensions.spaceMd),
            FilledButton(
              key: const Key('save_purchase'),
              onPressed: (saving || blocked != null)
                  ? null
                  : () => cubit.submit(
                      supplierReference: _reference.text,
                      notes: _notes.text,
                    ),
              child: saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save draft'),
            ),
            const SizedBox(height: AppDimensions.spaceSm),
            Text(
              'A draft does not change your stock. Post it from the purchase '
              'screen when the goods are received.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(
    BuildContext context,
    PurchaseFormCubit cubit,
    PurchaseFormState state,
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
    return Card(
      key: Key('line_$index'),
      child: ListTile(
        onTap: enabled
            ? () => _editLine(context, cubit, state, index: index)
            : null,
        title: Text(preview?.productName ?? product?.name ?? 'Unknown product'),
        subtitle: Text(
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
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (preview != null)
              Text(
                formatter.format(preview.total),
                key: Key('line_total_$index'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            IconButton(
              key: Key('remove_line_$index'),
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline),
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
          border: const OutlineInputBorder(),
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
