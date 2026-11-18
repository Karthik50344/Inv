import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_bloc.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_event.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_state.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Customer list with search and archive toggle.
class CustomersPage extends StatelessWidget {
  /// Creates the page. Provide a [CustomerBloc] above it.
  const CustomersPage({super.key});

  Future<void> _push(
    BuildContext context,
    String name, {
    Map<String, String> params = const {},
  }) async {
    final bloc = context.read<CustomerBloc>();
    await context.pushNamed(name, pathParameters: params);
    bloc.add(const CustomersRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerBloc, CustomerState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<CustomerBloc>();
        return Scaffold(
          appBar: const AppAppBar(title: 'Customers'),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_customer'),
            onPressed: () => _push(context, RouteNames.customerNew),
            icon: const Icon(Icons.add),
            label: const Text('Customer'),
          ),
          body: Column(
            children: [
              AppSearchField(
                hintText: 'Search name, phone or email',
                onChanged: (query) => bloc.add(CustomersSearchChanged(query)),
              ),
              SwitchListTile(
                dense: true,
                title: const Text('Show archived'),
                value: state.includeArchived,
                onChanged: (value) => bloc.add(
                  CustomersArchivedFilterChanged(includeArchived: value),
                ),
              ),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, CustomerState state) {
    final bloc = context.read<CustomerBloc>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load customers.',
          onRetry: () => bloc.add(const CustomersRefreshed()),
        );
      case ViewStatus.empty:
        final filtered = state.query.isNotEmpty || state.includeArchived;
        return EmptyState(
          icon: Icons.people_outline,
          title: filtered ? 'No matching customers' : 'No customers yet',
          message: filtered
              ? 'Try changing the search or filters.'
              : 'Add your first customer to get started.',
          action: filtered
              ? null
              : AppButton(
                  key: const Key('empty_add_customer'),
                  label: 'Add customer',
                  icon: Icons.add,
                  onPressed: () => _push(context, RouteNames.customerNew),
                ),
        );
      case ViewStatus.loaded:
        final tokens = context.appColors;
        final theme = Theme.of(context);
        return AppRefreshIndicator(
          onRefresh: () async => bloc.add(const CustomersRefreshed()),
          child: ListView.separated(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              96,
            ),
            itemCount: state.customers.length,
            separatorBuilder: (_, _) => AppSpacing.gap8,
            itemBuilder: (context, index) {
              final item = state.customers[index];
              final contact = [
                item.phone,
                item.email,
              ].whereType<String>().join(' · ');
              return AppCard(
                key: Key('customer_${item.id}'),
                padding: const EdgeInsets.all(AppSpacing.s12),
                onTap: () => _push(
                  context,
                  RouteNames.customerDetail,
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
