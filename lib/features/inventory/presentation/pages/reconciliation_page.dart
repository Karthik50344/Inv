import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/inventory/domain/entities/reconciliation.dart';
import 'package:inventrix/features/inventory/presentation/bloc/reconciliation_cubit.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

/// Compares every stock balance with the ledger and can repair differences.
class ReconciliationPage extends StatelessWidget {
  /// Creates the page. Provide a [ReconciliationCubit] above it.
  const ReconciliationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReconciliationCubit, ReconciliationState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<ReconciliationCubit>();
        final busy =
            state.status == ReconciliationStatus.running ||
            state.status == ReconciliationStatus.repairing;
        final report = state.report;
        return Scaffold(
          appBar: AppBar(title: const Text('Reconcile stock')),
          body: ListView(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            children: [
              const Text(
                'The stock ledger is the source of truth. This check compares '
                'every product balance with the sum of its ledger entries.',
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              FilledButton.icon(
                key: const Key('run_reconciliation'),
                onPressed: busy ? null : cubit.run,
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Check balances'),
              ),
              const SizedBox(height: AppDimensions.spaceMd),
              if (busy) const SizedBox(height: 80, child: LoadingIndicator()),
              if (!busy && report != null)
                ..._result(context, cubit, state, report),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _result(
    BuildContext context,
    ReconciliationCubit cubit,
    ReconciliationState state,
    ReconciliationReport report,
  ) {
    const formatter = MoneyFormatter();
    final repaired = state.repairedCount;
    return [
      if (repaired != null && repaired > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spaceMd),
          child: Text(
            'Corrected $repaired balance${repaired == 1 ? '' : 's'} '
            'from the ledger.',
            key: const Key('repaired_message'),
          ),
        ),
      if (report.isConsistent)
        ListTile(
          key: const Key('reconciliation_ok'),
          leading: const Icon(Icons.check_circle_outline, color: Colors.green),
          title: const Text('All balances match the ledger'),
          subtitle: Text('${report.productsChecked} products checked'),
        )
      else ...[
        ListTile(
          key: const Key('reconciliation_mismatch'),
          leading: Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
          title: Text(
            '${report.mismatches.length} '
            'balance${report.mismatches.length == 1 ? '' : 's'} differ '
            'from the ledger',
          ),
          subtitle: Text('${report.productsChecked} products checked'),
        ),
        for (final m in report.mismatches)
          ListTile(
            dense: true,
            title: Text(m.productId),
            subtitle: Text(
              'Stored ${m.actualQuantity.toDecimalString()} / '
              '${formatter.format(m.actualValue)}  →  '
              'Ledger ${m.expectedQuantity.toDecimalString()} / '
              '${formatter.format(m.expectedValue)}'
              '${m.balanceMissing ? ' (balance missing)' : ''}',
            ),
          ),
        const SizedBox(height: AppDimensions.spaceMd),
        FilledButton(
          key: const Key('repair_balances'),
          onPressed: () async {
            final confirmed = await showConfirmationDialog(
              context,
              title: 'Repair balances?',
              message:
                  'Balances will be rewritten from the ledger and each '
                  'change is recorded in the audit log. The ledger itself is '
                  'never changed.',
              confirmLabel: 'Repair',
              destructive: true,
            );
            if (confirmed) {
              await cubit.repair();
            }
          },
          child: const Text('Repair from ledger'),
        ),
      ],
    ];
  }
}
