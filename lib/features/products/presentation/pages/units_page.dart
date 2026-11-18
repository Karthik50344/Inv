import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/presentation/bloc/unit_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/unit_state.dart';
import 'package:inventrix/features/products/presentation/widgets/unit_form_dialog.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

enum _UnitAction { edit, archive, restore }

/// Lists units of measurement with search, archive and restore.
class UnitsPage extends StatelessWidget {
  /// Creates the page. Provide a [UnitCubit] above it.
  const UnitsPage({super.key});

  Future<void> _openForm(BuildContext context, {UnitOfMeasure? unit}) {
    final cubit = context.read<UnitCubit>();
    return showDialog<bool>(
      context: context,
      builder: (_) => UnitFormDialog(
        unit: unit,
        onSubmit: (name, symbol, places) => unit == null
            ? cubit.create(name: name, symbol: symbol, decimalPlaces: places)
            : cubit.update(
                id: unit.id,
                name: name,
                symbol: symbol,
                decimalPlaces: places,
              ),
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    _UnitAction action,
    UnitOfMeasure unit,
  ) async {
    final cubit = context.read<UnitCubit>();
    switch (action) {
      case _UnitAction.edit:
        await _openForm(context, unit: unit);
      case _UnitAction.archive:
        final confirmed = await showConfirmationDialog(
          context,
          title: 'Archive unit?',
          message: '"${unit.name}" can no longer be chosen for new products.',
          confirmLabel: 'Archive',
          destructive: true,
        );
        if (confirmed) {
          await cubit.archive(unit.id);
        }
      case _UnitAction.restore:
        await cubit.restore(unit.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UnitCubit, UnitState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        return Scaffold(
          appBar: const AppAppBar(title: 'Units'),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_unit'),
            onPressed: () => _openForm(context),
            icon: const Icon(Icons.add),
            label: const Text('Unit'),
          ),
          body: Column(
            children: [
              AppSearchField(
                hintText: 'Search units',
                onChanged: context.read<UnitCubit>().search,
              ),
              SwitchListTile(
                title: const Text('Show archived'),
                value: state.includeArchived,
                onChanged: (value) =>
                    context.read<UnitCubit>().setIncludeArchived(value: value),
              ),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, UnitState state) {
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load units.',
          onRetry: context.read<UnitCubit>().load,
        );
      case ViewStatus.empty:
        final searching = state.query.isNotEmpty;
        return EmptyState(
          icon: Icons.straighten,
          title: searching ? 'No matches' : 'No units yet',
          message: searching
              ? 'Try a different search.'
              : 'Units define how products are counted, like pieces or kg.',
          action: searching
              ? null
              : AppButton(
                  key: const Key('add_common_units'),
                  label: 'Add common units',
                  icon: Icons.auto_awesome_outlined,
                  onPressed: context.read<UnitCubit>().addCommonUnits,
                ),
        );
      case ViewStatus.loaded:
        final tokens = context.appColors;
        return AppRefreshIndicator(
          onRefresh: context.read<UnitCubit>().load,
          child: ListView.separated(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              96,
            ),
            itemCount: state.units.length,
            separatorBuilder: (_, _) => AppSpacing.gap8,
            itemBuilder: (context, index) {
              final unit = state.units[index];
              return AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s8,
                  AppSpacing.s4,
                  AppSpacing.s8,
                ),
                child: Row(
                  children: [
                    Icon(
                      unit.isArchived
                          ? Icons.archive_outlined
                          : Icons.straighten,
                      color: tokens.textSecondary,
                    ),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${unit.name} (${unit.symbol})',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            unit.decimalPlaces == 0
                                ? 'Whole numbers only'
                                : 'Up to ${unit.decimalPlaces} decimal places',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<_UnitAction>(
                      tooltip: 'Unit actions',
                      onSelected: (action) =>
                          _onAction(context, action, unit),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: _UnitAction.edit,
                          child: Text('Edit'),
                        ),
                        if (unit.isArchived)
                          const PopupMenuItem(
                            value: _UnitAction.restore,
                            child: Text('Restore'),
                          )
                        else
                          const PopupMenuItem(
                            value: _UnitAction.archive,
                            child: Text('Archive'),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
    }
  }
}
