import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/inventory/domain/entities/reconciliation.dart';
import 'package:inventrix/features/inventory/presentation/bloc/reconciliation_cubit.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

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
          appBar: const AppAppBar(title: 'Reconcile stock'),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            children: [
              const AppCard(
                tone: AppTone.info,
                child: Text(
                  'The stock ledger is the source of truth. This check '
                  'compares every product balance with the sum of its '
                  'ledger entries.',
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              AppButton(
                key: const Key('run_reconciliation'),
                label: 'Check balances',
                icon: Icons.fact_check_outlined,
                expand: true,
                loading: busy,
                onPressed: cubit.run,
              ),
              const SizedBox(height: AppSpacing.s16),
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
          padding: const EdgeInsets.only(bottom: AppSpacing.s16),
          child: Text(
            'Corrected $repaired balance${repaired == 1 ? '' : 's'} '
            'from the ledger.',
            key: const Key('repaired_message'),
          ),
        ),
      if (report.isConsistent)
        AppCard(
          key: const Key('reconciliation_ok'),
          tone: AppTone.success,
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: context.appColors.success.onContainer,
              ),
              AppSpacing.hGap12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('All balances match the ledger'),
                    Text('${report.productsChecked} products checked'),
                  ],
                ),
              ),
            ],
          ),
        )
      else ...[
        AppCard(
          key: const Key('reconciliation_mismatch'),
          tone: AppTone.danger,
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: context.appColors.danger.onContainer,
              ),
              AppSpacing.hGap12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report.mismatches.length} '
                      'balance${report.mismatches.length == 1 ? '' : 's'} '
                      'differ from the ledger',
                    ),
                    Text('${report.productsChecked} products checked'),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (final m in report.mismatches)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.productId,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    'Stored ${m.actualQuantity.toDecimalString()} / '
                    '${formatter.format(m.actualValue)}  →  '
                    'Ledger ${m.expectedQuantity.toDecimalString()} / '
                    '${formatter.format(m.expectedValue)}'
                    '${m.balanceMissing ? ' (balance missing)' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.s16),
        AppButton(
          key: const Key('repair_balances'),
          label: 'Repair from ledger',
          icon: Icons.build_outlined,
          expand: true,
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
        ),
      ],
    ];
  }
}
