import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_bloc.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_event.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_state.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';

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
          appBar: AppBar(title: const Text('Suppliers')),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_supplier'),
            onPressed: () => _push(context, RouteNames.supplierNew),
            icon: const Icon(Icons.add),
            label: const Text('Supplier'),
          ),
          body: Column(
            children: [
              SearchField(
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
        );
      case ViewStatus.loaded:
        const formatter = MoneyFormatter();
        return ListView.separated(
          itemCount: state.suppliers.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = state.suppliers[index];
            final contact = [
              item.phone,
              item.email,
            ].whereType<String>().join(' · ');
            return ListTile(
              key: Key('supplier_${item.id}'),
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
                RouteNames.supplierDetail,
                params: {'id': item.id},
              ),
            );
          },
        );
    }
  }
}
