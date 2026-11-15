import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_form_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/party_form_fields.dart';

/// Create/edit supplier form. Pops with `true` after a successful save.
class SupplierFormPage extends StatefulWidget {
  /// Creates the form; pass [supplierId] to edit. Provide a [SupplierFormCubit]
  /// above it.
  const SupplierFormPage({this.supplierId, super.key});

  /// Supplier being edited, or `null` to create.
  final String? supplierId;

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  final PartyFormControllers _controllers = PartyFormControllers();
  bool _populated = false;

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  void _populate(SupplierFormState state) {
    final existing = state.supplier;
    if (_populated || existing == null) {
      return;
    }
    _populated = true;
    _controllers.fill(
      name: existing.name,
      phone: existing.phone,
      email: existing.email,
      address: existing.address,
      city: existing.city,
      state: existing.state,
      postalCode: existing.postalCode,
      taxId: existing.taxId,
      notes: existing.notes,
      openingBalance: existing.openingBalance.isZero
          ? ''
          : existing.openingBalance.toPlainString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SupplierFormCubit, SupplierFormState>(
      listenWhen: (previous, current) =>
          previous.loadStatus != current.loadStatus ||
          previous.submitStatus != current.submitStatus ||
          (current.message != null && current.message != previous.message),
      listener: (context, state) {
        if (state.loadStatus == FormLoadStatus.ready) {
          setState(() => _populate(state));
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
        final cubit = context.read<SupplierFormCubit>();
        final editing = widget.supplierId != null;
        return Scaffold(
          appBar: AppBar(
            title: Text(editing ? 'Edit supplier' : 'New supplier'),
          ),
          body: switch (state.loadStatus) {
            FormLoadStatus.loading => const LoadingIndicator(),
            FormLoadStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Supplier not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            FormLoadStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the form.',
              onRetry: () => cubit.load(supplierId: widget.supplierId),
            ),
            FormLoadStatus.ready => Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                children: [
                  PartyFormFields(
                    controllers: _controllers,
                    fieldErrors: state.fieldErrors,
                    currencyCode: state.currency?.currencyCode ?? '',
                    openingBalanceHint:
                        'Positive: amount you owe the supplier. Negative: a credit.',
                  ),
                  FilledButton(
                    key: const Key('save_supplier'),
                    onPressed: state.submitStatus == SubmitStatus.submitting
                        ? null
                        : () {
                            if (_formKey.currentState?.validate() ?? false) {
                              cubit.submit(_controllers.toDraft());
                            }
                          },
                    child: state.submitStatus == SubmitStatus.submitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          },
        );
      },
    );
  }
}
