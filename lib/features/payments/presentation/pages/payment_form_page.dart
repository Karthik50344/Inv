import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_form_cubit.dart';
import 'package:inventrix/features/purchases/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Record a payment received from a customer or made to a supplier, with
/// optional allocation to invoices.
class PaymentFormPage extends StatefulWidget {
  /// Creates the page.
  const PaymentFormPage({required this.type, super.key});

  /// Customer receipt or supplier payment.
  final PartyType type;

  @override
  State<PaymentFormPage> createState() => _PaymentFormPageState();
}

class _PaymentFormPageState extends State<PaymentFormPage> {
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _sync(TextEditingController controller, String value) {
    if (controller.text != value) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCustomer = widget.type == PartyType.customer;
    return BlocConsumer<PaymentFormCubit, PaymentFormState>(
      listener: (context, state) {
        _sync(_amount, state.amount);
        if (state.status == PaymentFormStatus.saved) {
          showAppMessage(context, 'Recorded ${state.saved!.number}.');
          context.pop();
        } else if (state.message != null) {
          showAppMessage(context, state.message!);
        }
      },
      builder: (context, state) {
        final cubit = context.read<PaymentFormCubit>();
        final title = isCustomer ? 'Receive payment' : 'Pay supplier';
        if (state.status == PaymentFormStatus.loading) {
          return Scaffold(
            appBar: AppAppBar(title: title),
            body: const LoadingIndicator(),
          );
        }
        if (state.status == PaymentFormStatus.failure) {
          return Scaffold(
            appBar: AppAppBar(title: title),
            body: ErrorState(
              message: state.message ?? 'Could not open the form.',
              onRetry: () => cubit.load(type: widget.type),
            ),
          );
        }
        const formatter = MoneyFormatter();
        final saving = state.status == PaymentFormStatus.saving;
        final unallocated = state.unallocated;
        return Scaffold(
          appBar: AppAppBar(title: title),
          body: ListView(
            padding: AppSpacing.page,
            children: [
              AppSectionHeader(
                title: isCustomer ? 'Who paid' : 'Who is being paid',
                padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey('party_${state.partyId}_${state.parties.length}'),
                initialValue: state.partyId,
                decoration: InputDecoration(
                  labelText: widget.type.label,
                  errorText: state.fieldErrors['party'],
                ),
                items: [
                  for (final p in state.parties)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: state.partyLocked || saving
                    ? null
                    : (value) {
                        if (value != null) {
                          cubit.selectParty(value);
                        }
                      },
              ),
              const AppSectionHeader(
                title: 'Payment',
                padding: EdgeInsets.only(
                  top: AppSpacing.s20,
                  bottom: AppSpacing.s12,
                ),
              ),
              TextField(
                key: const Key('payment_amount'),
                controller: _amount,
                enabled: !saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Amount (${state.currency?.currencyCode ?? ''})',
                  errorText: state.fieldErrors['amount'],
                ),
                onChanged: cubit.setAmount,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('method_${state.methodId}'),
                initialValue: state.methodId,
                decoration: InputDecoration(
                  labelText: 'Payment method',
                  errorText: state.fieldErrors['method'],
                ),
                items: [
                  for (final m in state.methods)
                    DropdownMenuItem(value: m.id, child: Text(m.name)),
                ],
                onChanged: saving
                    ? null
                    : (value) {
                        if (value != null) {
                          cubit.selectMethod(value);
                        }
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(formatDocumentDate(state.date)),
                trailing: Icon(
                  Icons.calendar_today_outlined,
                  color: context.appColors.textSecondary,
                ),
                onTap: saving
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: state.date,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          cubit.setDate(picked);
                        }
                      },
              ),
              TextField(
                key: const Key('payment_reference'),
                controller: _reference,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Reference (optional)',
                ),
                onChanged: cubit.setReference,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                enabled: !saving,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes (optional)'),
                onChanged: cubit.setNotes,
              ),
              AppSpacing.gap16,
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Apply to invoices',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    'Oldest first',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                  Switch(
                    key: const Key('auto_allocate'),
                    value: state.autoAllocate,
                    onChanged: saving
                        ? null
                        : (value) => cubit.setAutoAllocate(value: value),
                  ),
                ],
              ),
              if (state.partyId == null)
                Text('Choose a ${widget.type.label.toLowerCase()} first.')
              else if (state.invoices.isEmpty)
                const Text(
                  'No unpaid invoices. The amount is kept as credit and can '
                  'be applied to a later invoice.',
                ),
              for (final invoice in state.invoices)
                _AllocationRow(
                  key: Key('allocation_${invoice.id}'),
                  label:
                      '${invoice.displayNumber} · outstanding '
                      '${formatter.format(invoice.outstanding)}',
                  value: state.allocations[invoice.id] ?? '',
                  error: state.fieldErrors['allocation_${invoice.id}'],
                  enabled: !saving,
                  onChanged: (text) => cubit.setAllocation(invoice.id, text),
                ),
              if (unallocated != null && state.amountMoney != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    unallocated.isNegative
                        ? 'Allocated ${formatter.format(unallocated.abs())} '
                              'more than the amount.'
                        : unallocated.isZero
                        ? 'Fully allocated.'
                        : 'Kept as credit: ${formatter.format(unallocated)}',
                    key: const Key('unallocated_text'),
                    style: TextStyle(
                      color: unallocated.isNegative
                          ? context.appColors.danger.solid
                          : context.appColors.textSecondary,
                    ),
                  ),
                ),
              AppSpacing.gap16,
              AppButton(
                key: const Key('save_payment'),
                label: 'Save payment',
                icon: Icons.check,
                expand: true,
                loading: saving,
                onPressed: cubit.submit,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AllocationRow extends StatefulWidget {
  const _AllocationRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.error,
    super.key,
  });

  final String label;
  final String value;
  final String? error;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_AllocationRow> createState() => _AllocationRowState();
}

class _AllocationRowState extends State<_AllocationRow> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_AllocationRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: widget.error,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
