import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/presentation/bloc/tax_settings_cubit.dart';
import 'package:inventrix/features/taxation/presentation/support/tax_labels.dart';
import 'package:inventrix/features/taxation/presentation/widgets/tax_forms.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// One tax rule: its conditions and its tax lines (CGST 9%, SGST 9%, ...).
class TaxRulePage extends StatelessWidget {
  /// Creates the page for rule [ruleId].
  const TaxRulePage({required this.ruleId, super.key});

  /// The rule shown.
  final String ruleId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaxSettingsCubit, TaxSettingsState>(
      listenWhen: (a, b) => a.messageSerial != b.messageSerial && b.message != null,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final config = state.configuration;
        final rule = config?.rules.where((r) => r.id == ruleId).firstOrNull;
        return Scaffold(
          appBar: const AppAppBar(title: 'Tax rule'),
          body: switch (state.status) {
            ViewStatus.initial || ViewStatus.loading => const LoadingIndicator(),
            ViewStatus.failure || ViewStatus.empty => ErrorState(
              message: state.error ?? 'Could not load the tax settings.',
              onRetry: () => context.read<TaxSettingsCubit>().load(),
            ),
            ViewStatus.loaded => rule == null
                ? const ErrorState(message: 'This rule no longer exists.')
                : _Content(state: state, config: config!, rule: rule),
          },
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.config, required this.rule});

  final TaxSettingsState state;
  final TaxConfiguration config;
  final TaxRule rule;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TaxSettingsCubit>();
    final theme = Theme.of(context);
    final lines = config.components.where((c) => c.taxRuleId == rule.id).toList()
      ..sort((a, b) => a.calculationOrder.compareTo(b.calculationOrder));
    final activeLines = lines.where((c) => c.isActive).length;
    final category = config.category(rule.taxCategoryId);
    final until = rule.effectiveUntil;
    return AppContentWidth(
      child: ListView(
        padding: AppSpacing.page,
        children: [
          Text(category?.name ?? 'Unknown category', style: theme.textTheme.headlineSmall),
          AppSpacing.gap8,
          Wrap(
            spacing: AppSpacing.s8,
            children: [
              if (!rule.isActive) const AppBadge(label: 'Switched off'),
              if (rule.isStackable) const AppBadge(label: 'Added to the main rule', tone: AppTone.info),
              if (activeLines == 0) const AppBadge(label: 'No tax lines: ignored', tone: AppTone.warning),
            ],
          ),
          AppSpacing.gap16,
          AppFactsCard(
            facts: [
              AppFact('Profile', config.profile(rule.taxProfileId)?.name ?? 'Unknown'),
              AppFact('Where', TaxLabels.place(config, rule.jurisdictionId)),
              AppFact('Locations', TaxLabels.relation(rule.supplyRelation)),
              AppFact('For', TaxLabels.transactionType(rule.transactionType)),
              AppFact('Goods or services', rule.supplyType == null ? 'Either' : (rule.supplyType == 'goods' ? 'Goods' : rule.supplyType == 'services' ? 'Services' : rule.supplyType!)),
              if (rule.customerTaxStatus != null) AppFact('Customer type', rule.customerTaxStatus),
              AppFact('Worked out as', TaxLabels.method(rule.calculationMethod)),
              AppFact('Valid', 'From ${DateFormatter.date(rule.effectiveFrom)}${until == null ? '' : ' to ${DateFormatter.date(until)}'}'),
              AppFact('Priority', '${rule.priority}'),
            ],
          ),
          AppButton(
            label: 'Edit rule',
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.text,
            onPressed: () => showTaxFormSheet(
              context,
              TaxRuleForm(id: rule.id, configuration: config, existing: rule, onSave: cubit.saveRule),
            ),
          ),
          AppSectionHeader(
            title: 'Tax lines',
            subtitle: 'What is charged under this rule',
            actionLabel: 'Add',
            onAction: () => _openForm(context, null, lines),
          ),
          if (lines.isEmpty)
            Text('Add at least one line, for example CGST 9%. A rule without lines is ignored.', style: theme.textTheme.bodyMedium)
          else
            for (final c in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.cardGap),
                child: Opacity(
                  opacity: c.isActive ? 1 : 0.6,
                  child: AppCard(
                    onTap: () => _openForm(context, c, lines),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rule.calculationMethod == TaxCalculationMethod.percentage
                                    ? '${c.name} ${TaxLabels.percent(c.rateBasisPoints)}'
                                    : '${c.name} ${TaxLabels.minorText(c.fixedAmountMinor ?? 0, state.currencyDecimals)} per unit',
                                style: theme.textTheme.titleSmall,
                              ),
                              AppSpacing.gap4,
                              Text(
                                'Step ${c.calculationOrder}'
                                '${c.isCompound ? ' · on price plus earlier tax' : ''}'
                                '${c.isRecoverable ? ' · claimable' : ''}'
                                '${c.isActive ? '' : ' · switched off'}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: (v) async {
                            if (v == 'edit') {
                              await _openForm(context, c, lines);
                            } else {
                              final failure = await cubit.setActive(TaxConfigKind.component, c.id, active: !c.isActive);
                              if (failure != null && context.mounted) {
                                showAppMessage(context, failure.message);
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(value: 'toggle', child: Text(c.isActive ? 'Switch off' : 'Switch on')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          AppSpacing.gap16,
          Text(
            'Changes affect new documents only. Documents already posted keep '
            'the tax lines they were made with.',
            style: theme.textTheme.bodySmall,
          ),
          AppSpacing.gap24,
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, TaxComponent? existing, List<TaxComponent> lines) {
    final cubit = context.read<TaxSettingsCubit>();
    final nextOrder = lines.isEmpty ? 1 : lines.map((c) => c.calculationOrder).reduce((a, b) => a > b ? a : b) + 1;
    return showTaxFormSheet(
      context,
      TaxComponentForm(
        id: cubit.newId(),
        rule: rule,
        nextOrder: nextOrder,
        currencyDecimals: state.currencyDecimals,
        existing: existing,
        onSave: cubit.saveComponent,
      ),
    );
  }
}
