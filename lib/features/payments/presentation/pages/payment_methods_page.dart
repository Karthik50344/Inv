import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_methods_cubit.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Create and archive payment methods.
class PaymentMethodsPage extends StatelessWidget {
  /// Creates the page.
  const PaymentMethodsPage({super.key});

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<PaymentMethodsCubit>();
    final controller = TextEditingController();
    String? error;
    final created = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, setState) => AlertDialog(
          title: const Text('New payment method'),
          content: TextField(
            key: const Key('method_name'),
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Name', errorText: error),
          ),
          actions: [
            AppButton(
              label: 'Cancel',
              variant: AppButtonVariant.text,
              size: AppButtonSize.small,
              onPressed: () => Navigator.of(dialog).pop(false),
            ),
            AppButton(
              key: const Key('save_method'),
              label: 'Add',
              size: AppButtonSize.small,
              onPressed: () async {
                final message = await cubit.create(controller.text);
                if (message == null) {
                  if (dialog.mounted) {
                    Navigator.of(dialog).pop(true);
                  }
                } else {
                  setState(() => error = message);
                }
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (created ?? false) {
      cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentMethodsCubit, PaymentMethodsState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<PaymentMethodsCubit>();
        return Scaffold(
          appBar: const AppAppBar(title: 'Payment methods'),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_method'),
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Add method'),
          ),
          body: switch (state.status) {
            ViewStatus.initial ||
            ViewStatus.loading => const LoadingIndicator(),
            ViewStatus.failure => ErrorState(
              message: state.message ?? 'Could not load methods.',
              onRetry: cubit.load,
            ),
            ViewStatus.empty || ViewStatus.loaded => ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s8,
                AppSpacing.s16,
                96,
              ),
              children: [
                for (final m in state.methods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: AppCard(
                      key: Key('method_${m.id}'),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s16,
                        AppSpacing.s8,
                        AppSpacing.s8,
                        AppSpacing.s8,
                      ),
                      child: Row(
                        children: [
                          m.id == state.defaultMethodId
                              ? Icon(
                                  Icons.star,
                                  key: const Key('default_method'),
                                  color: context.appColors.warning.solid,
                                )
                              : Icon(
                                  Icons.payments_outlined,
                                  color: context.appColors.textSecondary,
                                ),
                          AppSpacing.hGap12,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (m.id == state.defaultMethodId || m.isArchived)
                                  Text(
                                    [
                                      if (m.id == state.defaultMethodId)
                                        'Default',
                                      if (m.isArchived) 'Archived',
                                    ].join(' · '),
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color:
                                              context.appColors.textSecondary,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          if (!m.isArchived && m.id != state.defaultMethodId)
                            AppButton(
                              key: Key('make_default_${m.id}'),
                              label: 'Make default',
                              variant: AppButtonVariant.text,
                              size: AppButtonSize.small,
                              onPressed: () => cubit.setDefault(m.id),
                            ),
                          AppButton(
                            label: m.isArchived ? 'Restore' : 'Archive',
                            variant: AppButtonVariant.text,
                            size: AppButtonSize.small,
                            onPressed: () => cubit.setArchived(
                              m.id,
                              archived: !m.isArchived,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          },
        );
      },
    );
  }
}
