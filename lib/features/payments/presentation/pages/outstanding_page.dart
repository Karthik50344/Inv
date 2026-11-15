import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/presentation/bloc/balance_cubits.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

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
          appBar: AppBar(title: const Text('Outstanding balances')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
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
                ListTile(
                  key: const Key('outstanding_total'),
                  title: Text(isCustomer ? 'Total to collect' : 'Total to pay'),
                  trailing: Text(
                    formatter.format(state.total!),
                    style: Theme.of(context).textTheme.titleMedium,
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
        const formatter = MoneyFormatter();
        return ListView.separated(
          itemCount: state.balances.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final b = state.balances[index];
            return ListTile(
              key: Key('balance_${b.partyId}'),
              title: Text(b.partyName),
              subtitle: b.hasCredit
                  ? Text(
                      state.type == PartyType.customer
                          ? 'Advance from customer'
                          : 'Advance to supplier',
                    )
                  : null,
              trailing: Text(
                formatter.format(b.balance.abs()),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              onTap: () => context.pushNamed(
                state.type == PartyType.customer
                    ? RouteNames.customerDetail
                    : RouteNames.supplierDetail,
                pathParameters: {'id': b.partyId},
              ),
            );
          },
        );
    }
  }
}
