import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Who owes us money and whom we owe.
class OutstandingPage extends StatelessWidget {
  /// Creates the page.
  const OutstandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OutstandingCubit, OutstandingState>(
      builder: (context, state) {
        final cubit = context.read<OutstandingCubit>();
        const formatter = MoneyFormatter();
        final isCustomer = state.type == PartyType.customer;
        return Scaffold(
          appBar: const AppAppBar(title: 'Outstanding balances'),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s8,
                  AppSpacing.s16,
                  AppSpacing.s8,
                ),
                child: SegmentedButton<PartyType>(
                  key: const Key('outstanding_type'),
                  segments: const [
                    ButtonSegment(
                      value: PartyType.customer,
                      label: Text('Receivable'),
                      icon: Icon(Icons.south_west),
                    ),
                    ButtonSegment(
                      value: PartyType.supplier,
                      label: Text('Payable'),
                      icon: Icon(Icons.north_east),
                    ),
                  ],
                  selected: {state.type},
                  onSelectionChanged: (value) => cubit.load(value.first),
                ),
              ),
              if (state.total != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    0,
                    AppSpacing.s16,
                    AppSpacing.s8,
                  ),
                  child: AppCard(
                    key: const Key('outstanding_total'),
                    tone: isCustomer ? AppTone.success : AppTone.warning,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            isCustomer ? 'Total to collect' : 'Total to pay',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          formatter.format(state.total!),
                          style: context.appText.financialMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: _body(context, state, cubit)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    OutstandingState state,
    OutstandingCubit cubit,
  ) {
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load balances.',
          onRetry: cubit.load,
        );
      case ViewStatus.empty:
        return EmptyState(
          icon: Icons.check_circle_outline,
          title: 'All settled',
          message: state.type == PartyType.customer
              ? 'No customer owes you anything.'
              : 'You do not owe any supplier.',
        );
      case ViewStatus.loaded:
        final tokens = context.appColors;
        return AppRefreshIndicator(
          onRefresh: cubit.load,
          child: ListView.separated(
            physics: AppRefreshIndicator.physics,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s4,
              AppSpacing.s16,
              AppSpacing.s24,
            ),
            itemCount: state.balances.length,
            separatorBuilder: (_, _) => AppSpacing.gap8,
            itemBuilder: (context, index) {
              final b = state.balances[index];
              return AppCard(
                key: Key('balance_${b.partyId}'),
                padding: const EdgeInsets.all(AppSpacing.s12),
                onTap: () => context.pushNamed(
                  state.type == PartyType.customer
                      ? RouteNames.customerDetail
                      : RouteNames.supplierDetail,
                  pathParameters: {'id': b.partyId},
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.partyName,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (b.hasCredit)
                            Text(
                              state.type == PartyType.customer
                                  ? 'Advance from customer'
                                  : 'Advance to supplier',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: tokens.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    AppSpacing.hGap8,
                    AppCurrencyText(b.balance.abs()),
                  ],
                ),
              );
            },
          ),
        );
    }
  }
}
