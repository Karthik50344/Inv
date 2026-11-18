import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/presentation/bloc/tax_rates_cubit.dart';
import 'package:inventrix/features/settings/presentation/widgets/settings_tiles.dart';
import 'package:inventrix/features/settings/presentation/widgets/tax_rate_form_dialog.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Tax rates: add, edit, archive, and the defaults for new products.
class TaxRatesPage extends StatelessWidget {
  /// Creates the page.
  const TaxRatesPage({super.key});

  Future<void> _edit(BuildContext context, {TaxRate? rate}) async {
    final cubit = context.read<TaxRatesCubit>();
    await showDialog<TaxRate>(
      context: context,
      builder: (_) => TaxRateFormDialog(
        initial: rate,
        onSubmit: (name, percent, exempt) => rate == null
            ? cubit.create(name: name, ratePercent: percent, isExempt: exempt)
            : cubit.update(
                id: rate.id,
                name: name,
                ratePercent: percent,
                isExempt: exempt,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaxRatesCubit, TaxRatesState>(
      listenWhen: (a, b) =>
          b.message != null && a.messageSerial != b.messageSerial,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<TaxRatesCubit>();
        return Scaffold(
          appBar: const AppAppBar(title: 'Tax rates'),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_tax_rate'),
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('Add rate'),
          ),
          body: AppContentWidth(child: switch (state.status) {
            ViewStatus.initial ||
            ViewStatus.loading => const LoadingIndicator(),
            ViewStatus.failure => ErrorState(
              message: state.message ?? 'Could not load tax rates.',
              onRetry: cubit.load,
            ),
            _ => _content(context, state, cubit),
          }),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    TaxRatesState state,
    TaxRatesCubit cubit,
  ) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s8,
        AppSpacing.s16,
        96,
      ),
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: SettingsSwitchTile(
            key: const Key('default_includes_tax'),
            icon: Icons.receipt_outlined,
            title: 'New products: prices include tax',
            value: state.defaultPriceIncludesTax,
            onChanged: (v) => cubit.setDefaultPriceIncludesTax(value: v),
          ),
        ),
        if (state.rates.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s24),
            child: EmptyState(
              icon: Icons.percent,
              title: 'No tax rates yet',
              message: 'Add the rates you charge, such as GST or VAT.',
              action: AppButton(
                key: const Key('empty_add_tax_rate'),
                label: 'Add rate',
                icon: Icons.add,
                onPressed: () => _edit(context),
              ),
            ),
          )
        else
          const AppSectionHeader(
            title: 'Rates',
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s4,
              AppSpacing.s20,
              AppSpacing.s4,
              AppSpacing.s8,
            ),
          ),
        for (final rate in state.rates)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: AppCard(
              key: Key('tax_${rate.id}'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s12,
                AppSpacing.s8,
                AppSpacing.s4,
                AppSpacing.s8,
              ),
              onTap: rate.isArchived ? null : () => _edit(context, rate: rate),
              child: Row(
                children: [
                  SettingsIcon(
                    rate.id == state.defaultRateId ? Icons.star : Icons.percent,
                    tone: rate.isArchived
                        ? AppTone.neutral
                        : rate.id == state.defaultRateId
                        ? AppTone.warning
                        : AppTone.brand,
                  ),
                  AppSpacing.hGap12,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rate.name, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (rate.isExempt)
                              'Exempt'
                            else
                              '${rate.percentLabel}%',
                            if (rate.id == state.defaultRateId)
                              'Default for new products',
                            if (rate.isArchived) 'Archived',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    key: Key('tax_menu_${rate.id}'),
                    onSelected: (v) {
                      switch (v) {
                        case 'default':
                          cubit.setDefault(rate.id);
                        case 'clear':
                          cubit.setDefault(null);
                        case 'archive':
                          cubit.setArchived(rate.id, archived: true);
                        case 'restore':
                          cubit.setArchived(rate.id, archived: false);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!rate.isArchived && rate.id != state.defaultRateId)
                        const PopupMenuItem(
                          value: 'default',
                          child: Text('Use for new products'),
                        ),
                      if (rate.id == state.defaultRateId)
                        const PopupMenuItem(
                          value: 'clear',
                          child: Text('Clear default'),
                        ),
                      PopupMenuItem(
                        value: rate.isArchived ? 'restore' : 'archive',
                        child: Text(rate.isArchived ? 'Restore' : 'Archive'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
