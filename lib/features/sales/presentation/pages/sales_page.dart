import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_event.dart';
import 'package:inventrix/features/sales/presentation/widgets/date_text.dart';
import 'package:inventrix/features/sales/presentation/widgets/sales_status_chip.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Sales invoices with search, status filter and the approval switch.
class SalesPage extends StatelessWidget {
  /// Creates the page. Provide a [SalesBloc] above it.
  const SalesPage({super.key});

  Future<void> _open(
    BuildContext context,
    String name, {
    Map<String, String> params = const {},
  }) async {
    final bloc = context.read<SalesBloc>();
    await context.pushNamed(name, pathParameters: params);
    bloc.add(const SalesRefreshed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SalesBloc, SalesState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<SalesBloc>();
        return Scaffold(
          appBar: AppAppBar(
            title: 'Sales',
            actions: [
              PopupMenuButton<bool>(
                key: const Key('sales_menu'),
                tooltip: 'More',
                onSelected: (value) async {
                  final confirmed = await showConfirmationDialog(
                    context,
                    title: value
                        ? 'Require approval?'
                        : 'Stop requiring approval?',
                    message: value
                        ? 'New sales must be submitted and approved '
                              'before they can be posted.'
                        : 'Sales can be posted directly. Sales '
                              'already waiting for approval stay as they are.',
                    confirmLabel: 'Apply',
                  );
                  if (confirmed) {
                    bloc.add(SalesApprovalToggled(required: value));
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
            key: const Key('add_sale'),
            onPressed: () => _open(context, RouteNames.saleNew),
            icon: const Icon(Icons.add),
            label: const Text('New sale'),
          ),
          body: Column(
            children: [
              AppSearchField(
                hintText: 'Search number, customer or reference',
                onChanged: (query) => bloc.add(SalesSearchChanged(query)),
              ),
              _StatusFilters(selected: state.filter.status),
              Expanded(child: _body(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, SalesState state) {
    final bloc = context.read<SalesBloc>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load sales.',
          onRetry: () => bloc.add(const SalesRefreshed()),
        );
      case ViewStatus.empty:
        final filtered =
            state.filter.query.isNotEmpty || state.filter.status != null;
        return EmptyState(
          icon: Icons.shopping_cart_outlined,
          title: filtered ? 'No matching sales' : 'No sales yet',
          message: filtered
              ? 'Try a different search or status.'
              : 'Record what you sell to customers. Posting a sale '
                    'takes the items out of your stock.',
          action: filtered
              ? null
              : AppButton(
                  key: const Key('empty_add_sale'),
                  label: 'New sale',
                  icon: Icons.add,
                  onPressed: () => _open(context, RouteNames.saleNew),
                ),
        );
      case ViewStatus.loaded:
        final tokens = context.appColors;
        final theme = Theme.of(context);
        return AppRefreshIndicator(
          onRefresh: () async => bloc.add(const SalesRefreshed()),
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
              return AppCard(
                key: Key('sales_${item.id}'),
                padding: const EdgeInsets.all(AppSpacing.s12),
                onTap: () => _open(
                  context,
                  RouteNames.saleDetail,
                  params: {'id': item.id},
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.displayNumber} · ${item.customerName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatDocumentDate(item.invoiceDate)} · '
                            '${item.lineCount} item${item.lineCount == 1 ? '' : 's'}'
                            '${item.customerReference == null ? '' : ' · ${item.customerReference}'}',
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AppCurrencyText(item.total),
                        AppSpacing.gap4,
                        SalesStatusChip(status: item.status),
                      ],
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
    final bloc = context.read<SalesBloc>();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s4,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s8),
            child: AppChip(
              key: const Key('filter_all'),
              label: 'All',
              selected: selected == null,
              onSelected: (_) => bloc.add(const SalesStatusChanged(null)),
            ),
          ),
          for (final status in _statuses)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: AppChip(
                key: Key('filter_${status.dbName}'),
                label: status.label,
                selected: selected == status,
                onSelected: (_) => bloc.add(SalesStatusChanged(status)),
              ),
            ),
        ],
      ),
    );
  }
}
