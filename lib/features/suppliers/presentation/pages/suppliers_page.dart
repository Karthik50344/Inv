import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_bloc.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_event.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_state.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Supplier list with search and archive toggle.
class SuppliersPage extends StatelessWidget {
  /// Creates the page. Provide a [SupplierBloc] above it.
  const SuppliersPage({super.key});

  Future<void> _push(
    BuildContext context,
    String name, {
    Map<String, String> params = const {},
  }) async {
    final bloc = context.read<SupplierBloc>();
    await context.pushNamed(name, pathParameters: params);
    bloc.add(const SuppliersRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SupplierBloc, SupplierState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<SupplierBloc>();
        return Scaffold(
          appBar: const AppAppBar(title: 'Suppliers'),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_supplier'),
            onPressed: () => _push(context, RouteNames.supplierNew),
            icon: const Icon(Icons.add),
            label: const Text('Supplier'),
          ),
          body: Column(
            children: [
              AppSearchField(
                hintText: 'Search name, phone or email',
                onChanged: (query) => bloc.add(SuppliersSearchChanged(query)),
              ),
              SwitchListTile(
                dense: true,
                title: const Text('Show archived'),
                value: state.includeArchived,
                onChanged: (value) => bloc.add(
                  SuppliersArchivedFilterChanged(includeArchived: value),
                ),
              ),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, SupplierState state) {
    final bloc = context.read<SupplierBloc>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load suppliers.',
          onRetry: () => bloc.add(const SuppliersRefreshed()),
        );
      case ViewStatus.empty:
        final filtered = state.query.isNotEmpty || state.includeArchived;
        return EmptyState(
          icon: Icons.local_shipping_outlined,
          title: filtered ? 'No matching suppliers' : 'No suppliers yet',
          message: filtered
              ? 'Try changing the search or filters.'
              : 'Add your first supplier to get started.',
          action: filtered
              ? null
              : AppButton(
                  key: const Key('empty_add_supplier'),
                  label: 'Add supplier',
                  icon: Icons.add,
                  onPressed: () => _push(context, RouteNames.supplierNew),
                ),
        );
      case ViewStatus.loaded:
        final tokens = context.appColors;
        final theme = Theme.of(context);
        return AppRefreshIndicator(
          onRefresh: () async => bloc.add(const SuppliersRefreshed()),
          child: ListView.separated(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              96,
            ),
            itemCount: state.suppliers.length,
            separatorBuilder: (_, _) => AppSpacing.gap8,
            itemBuilder: (context, index) {
              final item = state.suppliers[index];
              final contact = [
                item.phone,
                item.email,
              ].whereType<String>().join(' · ');
              return AppCard(
                key: Key('supplier_${item.id}'),
                padding: const EdgeInsets.all(AppSpacing.s12),
                onTap: () => _push(
                  context,
                  RouteNames.supplierDetail,
                  params: {'id': item.id},
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.brand.container,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Text(
                            item.name.characters.first.toUpperCase(),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: tokens.brand.onContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (contact.isNotEmpty)
                            Text(
                              contact,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: tokens.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AppSpacing.hGap8,
                    if (item.isArchived)
                      const AppBadge(label: 'Archived')
                    else if (item.openingBalance.isZero)
                      Icon(Icons.chevron_right, color: tokens.textDisabled)
                    else
                      AppCurrencyText(item.openingBalance),
                  ],
                ),
              );
            },
          ),
        );
    }
  }
}
