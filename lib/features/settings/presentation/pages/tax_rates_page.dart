import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/presentation/bloc/tax_rates_cubit.dart';
import 'package:inventrix/features/settings/presentation/widgets/tax_rate_form_dialog.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

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
          appBar: AppBar(title: const Text('Tax rates')),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_tax_rate'),
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add),
            label: const Text('Add rate'),
          ),
          body: switch (state.status) {
            ViewStatus.initial ||
            ViewStatus.loading => const LoadingIndicator(),
            ViewStatus.failure => ErrorState(
              message: state.message ?? 'Could not load tax rates.',
              onRetry: cubit.load,
            ),
            _ => ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                SwitchListTile(
                  key: const Key('default_includes_tax'),
                  title: const Text('New products: prices include tax'),
                  value: state.defaultPriceIncludesTax,
                  onChanged: (v) => cubit.setDefaultPriceIncludesTax(value: v),
                ),
                for (final rate in state.rates)
                  ListTile(
                    key: Key('tax_${rate.id}'),
                    leading: Icon(
                      rate.id == state.defaultRateId
                          ? Icons.star
                          : Icons.percent,
                    ),
                    title: Text(rate.name),
                    subtitle: Text(
                      [
                        if (rate.isExempt)
                          'Exempt'
                        else
                          '${rate.percentLabel}%',
                        if (rate.id == state.defaultRateId)
                          'Default for new products',
                        if (rate.isArchived) 'Archived',
                      ].join(' · '),
                    ),
                    onTap: rate.isArchived
                        ? null
                        : () => _edit(context, rate: rate),
                    trailing: PopupMenuButton<String>(
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
                  ),
              ],
            ),
          },
        );
      },
    );
  }
}
