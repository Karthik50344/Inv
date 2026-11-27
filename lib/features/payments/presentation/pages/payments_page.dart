import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';
import 'package:inventrix/features/payments/presentation/bloc/payments_bloc.dart';
import 'package:inventrix/features/purchases/presentation/widgets/date_text.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Payment history: receipts, supplier payments and refunds.
class PaymentsPage extends StatelessWidget {
  /// Creates the page.
  const PaymentsPage({super.key});

  Future<void> _open(
    BuildContext context,
    String name, {
    Map<String, String> params = const {},
    Map<String, String> query = const {},
  }) async {
    final bloc = context.read<PaymentsBloc>();
    await context.pushNamed(name, pathParameters: params, queryParameters: query);
    bloc.add(const PaymentsRefreshed());
  }

  Future<void> _chooseType(BuildContext context) async {
    final type = await showModalBottomSheet<PartyType>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('new_receipt'),
              leading: const Icon(Icons.south_west),
              title: const Text('Receive from a customer'),
              onTap: () => Navigator.of(sheet).pop(PartyType.customer),
            ),
            ListTile(
              key: const Key('new_supplier_payment'),
              leading: const Icon(Icons.north_east),
              title: const Text('Pay a supplier'),
              onTap: () => Navigator.of(sheet).pop(PartyType.supplier),
            ),
          ],
        ),
      ),
    );
    if (type != null && context.mounted) {
      await _open(context, RouteNames.paymentNew, query: {'type': type.dbName});
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentsBloc, PaymentsState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<PaymentsBloc>();
        return Scaffold(
          appBar: AppAppBar(
            title: 'Payments',
            actions: [
              AppIconButton(
                key: const Key('open_outstanding'),
                tooltip: 'Outstanding balances',
                icon: Icons.account_balance_wallet_outlined,
                onPressed: () => _open(context, RouteNames.paymentOutstanding),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (value) {
                  if (value == 'methods') {
                    _open(context, RouteNames.paymentMethods);
                  } else {
                    bloc.add(
                      PaymentsReversedToggled(
                        show: !state.filter.includeReversed,
                      ),
                    );
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    key: Key('open_methods'),
                    value: 'methods',
                    child: Text('Payment methods'),
                  ),
                  PopupMenuItem(
                    key: const Key('toggle_reversed'),
                    value: 'reversed',
                    child: Text(
                      state.filter.includeReversed
                          ? 'Hide reversed payments'
                          : 'Show reversed payments',
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_payment'),
            onPressed: () => _chooseType(context),
            icon: const Icon(Icons.add),
            label: const Text('Record payment'),
          ),
          body: Column(
            children: [
              AppSearchField(
                hintText: 'Search number, party, method or reference',
                onChanged: (query) => bloc.add(PaymentsSearchChanged(query)),
              ),
              _Filters(state: state),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, PaymentsState state) {
    final bloc = context.read<PaymentsBloc>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load payments.',
          onRetry: () => bloc.add(const PaymentsRefreshed()),
        );
      case ViewStatus.empty:
        return EmptyState(
          icon: Icons.payments_outlined,
          title: 'No payments',
          message:
              'Record money received from customers or paid to suppliers. '
              'Payments settle invoices and update outstanding balances.',
          action: AppButton(
            key: const Key('empty_add_payment'),
            label: 'Record payment',
            icon: Icons.add,
            onPressed: () => _chooseType(context),
          ),
        );
      case ViewStatus.loaded:
        final tokens = context.appColors;
        final theme = Theme.of(context);
        return AppRefreshIndicator(
          onRefresh: () async => bloc.add(const PaymentsRefreshed()),
          child: ListView.separated(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              96,
            ),
            itemCount: state.items.length,
            separatorBuilder: (_, _) => AppSpacing.gap8,
            itemBuilder: (context, index) {
              final item = state.items[index];
              final sign = item.isMoneyIn ? '+' : '-';
              final colors = (item.isMoneyIn ? AppTone.success : AppTone.warning)
                  .colors(context);
              return AppCard(
                key: Key('payment_${item.id}'),
                padding: const EdgeInsets.all(AppSpacing.s12),
                onTap: () => _open(
                  context,
                  RouteNames.paymentDetail,
                  params: {'id': item.id},
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.container,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          item.isMoneyIn ? Icons.south_west : Icons.north_east,
                          size: 20,
                          color: colors.onContainer,
                        ),
                      ),
                    ),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.number} · ${item.partyName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              decoration: item.isReversed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatDocumentDate(item.paymentDate)} · ${item.methodName}'
                            '${item.reference == null ? '' : ' · ${item.reference}'}'
                            '${item.isReversed ? ' · Reversed' : ''}',
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
                    Text(
                      '$sign ${const MoneyFormatter().format(item.amount)}',
                      style: context.appText.financialSmall,
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

class _Filters extends StatelessWidget {
  const _Filters({required this.state});

  final PaymentsState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PaymentsBloc>();
    final filter = state.filter;
    Widget chip(String key, String label, bool selected, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.s8),
          child: AppChip(
            key: Key(key),
            label: label,
            selected: selected,
            onSelected: (_) => onTap(),
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s4,
        ),
        children: [
          chip(
            'filter_all',
            'All',
            filter.partyType == null && filter.kind == null,
            () {
              bloc
                ..add(const PaymentsPartyTypeChanged(null))
                ..add(const PaymentsKindChanged(null));
            },
          ),
          chip(
            'filter_customers',
            'Customers',
            filter.partyType == PartyType.customer,
            () => bloc.add(const PaymentsPartyTypeChanged(PartyType.customer)),
          ),
          chip(
            'filter_suppliers',
            'Suppliers',
            filter.partyType == PartyType.supplier,
            () => bloc.add(const PaymentsPartyTypeChanged(PartyType.supplier)),
          ),
          chip(
            'filter_refunds',
            'Refunds',
            filter.kind == PaymentKind.refund,
            () => bloc.add(const PaymentsKindChanged(PaymentKind.refund)),
          ),
        ],
      ),
    );
  }
}
