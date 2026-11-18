import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:inventrix/features/expenses/presentation/widgets/expense_formatters.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Expense history with search and status, category and date filters.
class ExpensesPage extends StatelessWidget {
  /// Creates the page. Provide an [ExpensesBloc] above it.
  const ExpensesPage({super.key});

  Future<void> _open(
    BuildContext context,
    String name, {
    Map<String, String> params = const {},
  }) async {
    final bloc = context.read<ExpensesBloc>();
    await context.pushNamed(name, pathParameters: params);
    bloc.add(const ExpensesRefreshed());
  }

  Future<void> _pickRange(BuildContext context, ExpensesState state) async {
    final bloc = context.read<ExpensesBloc>();
    final from = state.filter.from;
    final to = state.filter.to;
    final now = DateTime.now();
    final picked = await showAppDateRangePicker(
      context,
      first: DateTime(2000),
      last: DateTime(now.year + 1, 12, 31),
      initial: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked != null) {
      bloc.add(
        ExpensesRangeChanged(
          from: DateTime.utc(
            picked.start.year,
            picked.start.month,
            picked.start.day,
          ),
          to: DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpensesBloc, ExpensesState>(
      listenWhen: (previous, current) =>
          current.message != null && current.message != previous.message,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final bloc = context.read<ExpensesBloc>();
        return Scaffold(
          appBar: AppAppBar(
            title: 'Expenses',
            actions: [
              AppIconButton(
                key: const Key('open_expense_report'),
                tooltip: 'Report',
                icon: Icons.bar_chart_outlined,
                onPressed: () => _open(context, RouteNames.expenseReport),
              ),
              AppIconButton(
                key: const Key('open_expense_categories'),
                tooltip: 'Categories',
                icon: Icons.category_outlined,
                onPressed: () => _open(context, RouteNames.expenseCategories),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add_expense'),
            onPressed: () => _open(context, RouteNames.expenseNew),
            icon: const Icon(Icons.add),
            label: const Text('New expense'),
          ),
          body: AppContentWidth(child: Column(
            children: [
              AppSearchField(
                hintText: 'Search description, payee or category',
                onChanged: (query) => bloc.add(ExpensesSearchChanged(query)),
              ),
              _StatusFilters(selected: state.filter.status),
              _OtherFilters(
                state: state,
                onPickRange: () => _pickRange(context, state),
              ),
              if (state.postedTotal != null &&
                  state.status == ViewStatus.loaded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    AppSpacing.s4,
                    AppSpacing.s16,
                    AppSpacing.s8,
                  ),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Posted total of this list',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.appColors.textSecondary,
                              ),
                        ),
                        Text(
                          const MoneyFormatter().format(state.postedTotal!),
                          key: const Key('expenses_posted_total'),
                          style: context.appText.financialMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(child: _body(context, state)),
            ],
          )),
        );
      },
    );
  }

  Widget _body(BuildContext context, ExpensesState state) {
    final bloc = context.read<ExpensesBloc>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not load expenses.',
          onRetry: () => bloc.add(const ExpensesRefreshed()),
        );
      case ViewStatus.empty:
        final filtered = state.filter.isActive;
        return EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: filtered ? 'No matching expenses' : 'No expenses yet',
          message: filtered
              ? 'Try different filters.'
              : 'Record what the business spends: rent, utilities, '
                    'transport and more.',
          action: filtered
              ? null
              : AppButton(
                  key: const Key('empty_add_expense'),
                  label: 'New expense',
                  icon: Icons.add,
                  onPressed: () => _open(context, RouteNames.expenseNew),
                ),
        );
      case ViewStatus.loaded:
        const formatter = MoneyFormatter();
        final tokens = context.appColors;
        final theme = Theme.of(context);
        final brand = AppTone.brand.colors(context);
        return AppRefreshIndicator(
          onRefresh: () async => bloc.add(const ExpensesRefreshed()),
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
                key: Key('expense_${item.id}'),
                padding: const EdgeInsets.all(AppSpacing.s12),
                onTap: () => _open(
                  context,
                  RouteNames.expenseDetail,
                  params: {'id': item.id},
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: brand.container,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                          color: brand.onContainer,
                        ),
                      ),
                    ),
                    AppSpacing.hGap12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              formatExpenseDate(item.expenseDate),
                              item.categoryName,
                              if (item.payee != null) item.payee!,
                              item.displayNumber,
                            ].join(' · '),
                            maxLines: 2,
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatter.format(item.total),
                          style: context.appText.financialSmall,
                        ),
                        AppSpacing.gap4,
                        DocumentStatusChip(status: item.status),
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
    DocumentStatus.posted,
    DocumentStatus.voided,
    DocumentStatus.cancelled,
  ];

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ExpensesBloc>();
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
              onSelected: (_) => bloc.add(const ExpensesStatusChanged(null)),
            ),
          ),
          for (final status in _statuses)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: AppChip(
                key: Key('filter_${status.dbName}'),
                label: status.label,
                selected: selected == status,
                onSelected: (_) => bloc.add(ExpensesStatusChanged(status)),
              ),
            ),
        ],
      ),
    );
  }
}

class _OtherFilters extends StatelessWidget {
  const _OtherFilters({required this.state, required this.onPickRange});

  final ExpensesState state;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ExpensesBloc>();
    final from = state.filter.from;
    final to = state.filter.to;
    final hasRange = from != null && to != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s4,
        AppSpacing.s16,
        AppSpacing.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: AppDropdown<String?>(
              key: const Key('filter_category'),
              value: state.filter.categoryId,
              hint: 'All categories',
              prefixIcon: Icons.category_outlined,
              items: [
                const AppDropdownItem<String?>(
                  value: null,
                  label: 'All categories',
                ),
                for (final category in state.categories)
                  AppDropdownItem<String?>(
                    value: category.id,
                    label: category.isArchived
                        ? '${category.name} (archived)'
                        : category.name,
                  ),
              ],
              onChanged: (value) => bloc.add(ExpensesCategoryChanged(value)),
            ),
          ),
          AppSpacing.hGap8,
          InputChip(
            key: const Key('filter_range'),
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(
              hasRange
                  ? '${formatExpenseDate(from)} – ${formatExpenseDate(to)}'
                  : 'Any date',
            ),
            onPressed: onPickRange,
            onDeleted: hasRange
                ? () => bloc.add(const ExpensesRangeChanged())
                : null,
          ),
        ],
      ),
    );
  }
}
