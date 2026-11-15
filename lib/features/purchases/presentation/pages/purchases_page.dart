import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_bloc.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_event.dart';
import 'package:inventrix/features/purchases/presentation/widgets/date_text.dart';
import 'package:inventrix/features/purchases/presentation/widgets/purchase_status_chip.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/confirmation_dialog.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';

/// Purchase invoices with search, status filter and the approval switch.
class PurchasesPage extends StatelessWidget {
  /// Creates the page. Provide a [PurchaseBloc] above it.
  const PurchasesPage({super.key});

  Future<void> _open(
    BuildContext context,
    String name, {
    Map<String, String> params = const {},
  }) async {
    final bloc = context.read<PurchaseBloc>();
    await context.pushNamed(name, pathParameters: params);
    bloc.add(const PurchasesRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PurchaseBloc, PurchaseState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<PurchaseBloc>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Purchases'),
            actions: [
              PopupMenuButton<bool>(
                key: const Key('purchase_menu'),
                tooltip: 'More',
                onSelected: (value) async {
                  final confirmed = await showConfirmationDialog(
                    context,
                    title: value
                        ? 'Require approval?'
                        : 'Stop requiring approval?',
                    message: value
                        ? 'New purchases must be submitted and approved '
                              'before they can be posted.'
                        : 'Purchases can be posted directly. Purchases '
                              'already waiting for approval stay as they are.',
                    confirmLabel: 'Apply',
                  );
                  if (confirmed) {
                    bloc.add(PurchasesApprovalToggled(required: value));
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    key: const Key('toggle_approval'),
                    value: !state.approvalRequired,
                    child: Text(
                      state.approvalRequired
                          ? 'Stop requiring approval'
                          : 'Require approval before posting',
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_purchase'),
            onPressed: () => _open(context, RouteNames.purchaseNew),
            icon: const Icon(Icons.add),
            label: const Text('New purchase'),
          ),
          body: Column(
            children: [
              SearchField(
                hintText: 'Search number, supplier or reference',
                onChanged: (query) => bloc.add(PurchasesSearchChanged(query)),
              ),
              _StatusFilters(selected: state.filter.status),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, PurchaseState state) {
    final bloc = context.read<PurchaseBloc>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load purchases.',
          onRetry: () => bloc.add(const PurchasesRefreshed()),
        );
      case ViewStatus.empty:
        final filtered =
            state.filter.query.isNotEmpty || state.filter.status != null;
        return EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: filtered ? 'No matching purchases' : 'No purchases yet',
          message: filtered
              ? 'Try a different search or status.'
              : 'Record what you buy from suppliers. Posting a purchase '
                    'adds the items to your stock.',
        );
      case ViewStatus.loaded:
        const formatter = MoneyFormatter();
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: state.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = state.items[index];
            return ListTile(
              key: Key('purchase_${item.id}'),
              onTap: () => _open(
                context,
                RouteNames.purchaseDetail,
                params: {'id': item.id},
              ),
              title: Text('${item.displayNumber} · ${item.supplierName}'),
              subtitle: Text(
                '${formatDocumentDate(item.invoiceDate)} · '
                '${item.lineCount} item${item.lineCount == 1 ? '' : 's'}'
                '${item.supplierReference == null ? '' : ' · ${item.supplierReference}'}',
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(item.total),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  PurchaseStatusChip(status: item.status),
                ],
              ),
            );
          },
        );
    }
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({required this.selected});

  final DocumentStatus? selected;

  static const _statuses = [
    DocumentStatus.draft,
    DocumentStatus.pendingApproval,
    DocumentStatus.approved,
    DocumentStatus.posted,
    DocumentStatus.voided,
    DocumentStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<PurchaseBloc>();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              key: const Key('filter_all'),
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => bloc.add(const PurchasesStatusChanged(null)),
            ),
          ),
          for (final status in _statuses)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                key: Key('filter_${status.dbName}'),
                label: Text(status.label),
                selected: selected == status,
                onSelected: (_) => bloc.add(PurchasesStatusChanged(status)),
              ),
            ),
        ],
      ),
    );
  }
}
