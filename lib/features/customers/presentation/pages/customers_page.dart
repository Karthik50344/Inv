import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_bloc.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_event.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_state.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';

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
          appBar: AppBar(title: const Text('Customers')),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_customer'),
            onPressed: () => _push(context, RouteNames.customerNew),
            icon: const Icon(Icons.add),
            label: const Text('Customer'),
          ),
          body: Column(
            children: [
              SearchField(
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
        );
      case ViewStatus.loaded:
        const formatter = MoneyFormatter();
        return ListView.separated(
          itemCount: state.customers.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = state.customers[index];
            final contact = [
              item.phone,
              item.email,
            ].whereType<String>().join(' · ');
            return ListTile(
              key: Key('customer_${item.id}'),
              leading: CircleAvatar(
                child: Text(item.name.characters.first.toUpperCase()),
              ),
              title: Text(item.name),
              subtitle: contact.isEmpty ? null : Text(contact),
              trailing: item.isArchived
                  ? const Chip(label: Text('Archived'))
                  : (item.openingBalance.isZero
                        ? const Icon(Icons.chevron_right)
                        : Text(formatter.format(item.openingBalance))),
              onTap: () => _push(
                context,
                RouteNames.customerDetail,
                params: {'id': item.id},
              ),
            );
          },
        );
    }
  }
}
