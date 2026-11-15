import 'package:flutter/material.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/presentation/widgets/party_balance_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

/// Read-only supplier details with edit and archive actions.
class SupplierDetailPage extends StatelessWidget {
  /// Creates the page for [supplierId]. Provide a [SupplierDetailCubit] above.
  const SupplierDetailPage({required this.supplierId, super.key});

  /// Id of the supplier to show.
  final String supplierId;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SupplierDetailCubit, SupplierDetailState>(
      listenWhen: (previous, current) =>
          current.message != null &&
          current.status == DetailStatus.loaded &&
          current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<SupplierDetailCubit>();
        final item = state.supplier;
        return Scaffold(
          appBar: AppBar(
            title: Text(item?.name ?? 'Supplier'),
            actions: [
              if (item != null) ...[
                IconButton(
                  key: const Key('edit_supplier'),
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    await context.pushNamed(
                      RouteNames.supplierEdit,
                      pathParameters: {'id': item.id},
                    );
                    await cubit.load(item.id);
                  },
                ),
                IconButton(
                  key: const Key('toggle_archive_supplier'),
                  tooltip: item.isArchived ? 'Restore' : 'Archive',
                  icon: Icon(
                    item.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  onPressed: () async {
                    if (item.isArchived) {
                      await cubit.restore();
                      return;
                    }
                    final confirmed = await showConfirmationDialog(
                      context,
                      title: 'Archive supplier?',
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
              title: 'Supplier not found',
              message: 'It may have been removed or the link is invalid.',
            ),
            DetailStatus.failure => ErrorState(
              message: state.message ?? 'Could not load the supplier.',
              onRetry: () => cubit.load(supplierId),
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

  final SupplierDetailState state;

  @override
  Widget build(BuildContext context) {
    final item = state.supplier!;
    const formatter = MoneyFormatter();
    Widget row(String label, String? value) =>
        ListTile(dense: true, title: Text(label), trailing: Text(value ?? '—'));
    final address = [
      item.address,
      item.city,
      item.state,
      item.postalCode,
    ].whereType<String>().join(', ');
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        if (item.isArchived)
          const Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text('Archived')),
          ),
        row('Phone', item.phone),
        row('Email', item.email),
        row('Address', address.isEmpty ? null : address),
        row('Tax ID', item.taxId),
        row('Opening balance', formatter.format(item.openingBalance)),
        const Divider(),
        PartyBalanceCard(type: PartyType.supplier, partyId: item.id),
        if (item.notes != null) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceSm),
            child: Text(item.notes!),
          ),
        ],
      ],
    );
  }
}
