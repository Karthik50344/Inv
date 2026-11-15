import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/payments/presentation/bloc/payment_methods_cubit.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

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
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('save_method'),
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
              child: const Text('Add'),
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
          appBar: AppBar(title: const Text('Payment methods')),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_method'),
            onPressed: () => _add(context),
            icon: const Icon(Icons.add),
            label: const Text('Add method'),
          ),
          body: switch (state.status) {
            ViewStatus.initial || ViewStatus.loading => const LoadingIndicator(),
            ViewStatus.failure => ErrorState(
              message: state.message ?? 'Could not load methods.',
              onRetry: cubit.load,
            ),
            ViewStatus.empty || ViewStatus.loaded => ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final m in state.methods)
                  ListTile(
                    key: Key('method_${m.id}'),
                    title: Text(m.name),
                    subtitle: m.isArchived ? const Text('Archived') : null,
                    trailing: TextButton(
                      onPressed: () =>
                          cubit.setArchived(m.id, archived: !m.isArchived),
                      child: Text(m.isArchived ? 'Restore' : 'Archive'),
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
