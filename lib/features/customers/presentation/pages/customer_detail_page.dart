import 'package:material_ui/material_ui.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/presentation/widgets/party_balance_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Read-only customer details with edit and archive actions.
class CustomerDetailPage extends StatelessWidget {
  /// Creates the page for [customerId]. Provide a [CustomerDetailCubit] above.
  const CustomerDetailPage({required this.customerId, super.key});

  /// Id of the customer to show.
  final String customerId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CustomerDetailCubit, CustomerDetailState>(
      listenWhen: (previous, current) =>
          current.message != null &&
          current.status == DetailStatus.loaded &&
          current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<CustomerDetailCubit>();
        final item = state.customer;
        return Scaffold(
          appBar: AppAppBar(
            title: item?.name ?? 'Customer',
            actions: [
              if (item != null) ...[
                AppIconButton(
                  key: const Key('edit_customer'),
                  tooltip: 'Edit',
                  icon: Icons.edit_outlined,
                  onPressed: () async {
                    await context.pushNamed(
                      RouteNames.customerEdit,
                      pathParameters: {'id': item.id},
                    );
                    await cubit.load(item.id);
                  },
                ),
                AppIconButton(
                  key: const Key('toggle_archive_customer'),
                  tooltip: item.isArchived ? 'Restore' : 'Archive',
                  icon: item.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  onPressed: () async {
                    if (item.isArchived) {
                      await cubit.restore();
                      return;
                    }
                    final confirmed = await showConfirmationDialog(
                      context,
                      title: 'Archive customer?',
                      message:
                          'They will be hidden from lists. History is '
                          'kept and you can restore them later.',
                      confirmLabel: 'Archive',
                      destructive: true,
                    );
                    if (confirmed) {
                      await cubit.archive();
                    }
                  },
                ),
              ],
            ],
          ),
          body: switch (state.status) {
            DetailStatus.loading => const LoadingIndicator(),
            DetailStatus.notFound => const EmptyState(
              icon: Icons.search_off,
              title: 'Customer not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            DetailStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the customer.',
              onRetry: () => cubit.load(customerId),
            ),
            DetailStatus.loaded => _Details(state: state),
          },
        );
      },
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.state});

  final CustomerDetailState state;

  @override
  Widget build(BuildContext context) {
    final item = state.customer!;
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final address = [
      item.address,
      item.city,
      item.state,
      item.postalCode,
    ].whereType<String>().join(', ');
    final facts = <(String, String?)>[
      ('Phone', item.phone),
      ('Email', item.email),
      ('Address', address.isEmpty ? null : address),
      ('Tax ID', item.taxId),
      ('Opening balance', formatter.format(item.openingBalance)),
    ];
    return ListView(
      padding: AppSpacing.page,
      children: [
        if (item.isArchived)
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.s12),
              child: AppBadge(label: 'Archived'),
            ),
          ),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s4,
          ),
          child: Column(
            children: [
              for (var i = 0; i < facts.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s12,
                  ),
                  decoration: BoxDecoration(
                    border: i == facts.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: tokens.divider)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facts[i].$1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      AppSpacing.hGap16,
                      Expanded(
                        child: Text(
                          facts[i].$2 ?? '—',
                          textAlign: TextAlign.end,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AppSpacing.gap12,
        PartyBalanceCard(type: PartyType.customer, partyId: item.id),
        if (item.notes != null) ...[
          AppSpacing.gap12,
          AppCard(
            child: Text(
              item.notes!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
