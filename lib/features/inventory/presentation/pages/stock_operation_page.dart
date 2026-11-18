import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/inventory/presentation/bloc/stock_operation_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Form for opening stock, stock in and stock out. Pops with `true` after a
/// successful save.
class StockOperationPage extends StatefulWidget {
  /// Creates the page. Provide a [StockOperationCubit] above it.
  const StockOperationPage({
    required this.productId,
    required this.operation,
    super.key,
  });

  /// Product being changed.
  final String productId;

  /// Which operation this form performs.
  final StockOperation operation;

  @override
  State<StockOperationPage> createState() => _StockOperationPageState();
}

class _StockOperationPageState extends State<StockOperationPage> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _unitCost = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _quantity.dispose();
    _unitCost.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool get _needsReason => widget.operation != StockOperation.opening;
  bool get _hasCost => widget.operation != StockOperation.stockOut;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StockOperationCubit, StockOperationState>(
      listenWhen: (previous, current) =>
          previous.submitStatus != current.submitStatus ||
          (current.message != null && current.message != previous.message),
      listener: (context, state) {
        if (state.submitStatus == SubmitStatus.success) {
          context.pop(true);
          return;
        }
        if (state.message != null && state.loadStatus == FormLoadStatus.ready) {
          showAppMessage(context, state.message!);
        }
      },
      builder: (context, state) {
        final cubit = context.read<StockOperationCubit>();
        return Scaffold(
          appBar: AppAppBar(title: widget.operation.title),
          body: switch (state.loadStatus) {
            FormLoadStatus.loading => const LoadingIndicator(),
            FormLoadStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Product not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            FormLoadStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the form.',
              onRetry: () => cubit.load(widget.productId, widget.operation),
            ),
            FormLoadStatus.ready => _form(context, cubit, state),
          },
        );
      },
    );
  }

  Widget _form(
    BuildContext context,
    StockOperationCubit cubit,
    StockOperationState state,
  ) {
    final item = state.item!;
    final unit = state.unit;
    final symbol = unit?.symbol ?? '';
    final errors = state.fieldErrors;
    final blocked = state.blockedReason;
    final saving = state.submitStatus == SubmitStatus.submitting;
    final precision = unit == null
        ? null
        : (unit.decimalPlaces == 0
              ? 'Whole numbers only.'
              : 'Up to ${unit.decimalPlaces} decimal places.');
    Widget gap(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
      child: child,
    );
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.s16),
        children: [
          gap(
            AppCard(
              child: Text(
                '${item.product.name} · on hand '
                '${item.balance.quantityOnHand.toDecimalString()} $symbol',
                key: const Key('operation_summary'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          if (blocked != null)
            gap(
              AppCard(
                tone: AppTone.danger,
                child: Text(
                  blocked,
                  key: const Key('operation_blocked'),
                  style: TextStyle(color: context.appColors.danger.onContainer),
                ),
              ),
            ),
          gap(
            TextFormField(
              key: const Key('stock_quantity_input'),
              controller: _quantity,
              enabled: blocked == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Quantity *',
                helperText: precision,
                suffixText: symbol,
                errorText: errors['quantity'],
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Quantity is required.'
                  : null,
            ),
          ),
          if (_hasCost)
            gap(
              TextFormField(
                key: const Key('stock_unit_cost_input'),
                controller: _unitCost,
                enabled: blocked == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Unit cost',
                  prefixText: '${state.currency?.currencyCode ?? ''} ',
                  helperText: widget.operation == StockOperation.opening
                      ? 'Defaults to the purchase price.'
                      : 'Defaults to the current average cost.',
                  errorText: errors['unitCost'],
                ),
              ),
            ),
          if (_needsReason)
            gap(
              TextFormField(
                key: const Key('stock_reason_input'),
                controller: _reason,
                enabled: blocked == null,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Reason *',
                  errorText: errors['reason'],
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'A reason is required.'
                    : null,
              ),
            ),
          AppButton(
            key: const Key('save_stock_operation'),
            label: 'Save',
            icon: Icons.check,
            expand: true,
            loading: saving,
            onPressed: blocked != null
                ? null
                : () {
                    if (_formKey.currentState?.validate() ?? false) {
                      cubit.submit(
                        quantity: _quantity.text,
                        unitCost: _unitCost.text,
                        reason: _reason.text,
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }
}
