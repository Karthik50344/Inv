import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_names.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:inventrix/features/expenses/presentation/widgets/expense_formatters.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/document_status_chip.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';

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
    final now = DateTime.now();
    final from = state.filter.from;
    final to = state.filter.to;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: from != null && to != null
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
          appBar: AppBar(
            title: const Text('Expenses'),
            actions: [
              IconButton(
                key: const Key('open_expense_report'),
                tooltip: 'Report',
                icon: const Icon(Icons.bar_chart_outlined),
                onPressed: () => _open(context, RouteNames.expenseReport),
              ),
              IconButton(
                key: const Key('open_expense_categories'),
                tooltip: 'Categories',
                icon: const Icon(Icons.category_outlined),
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
          body: Column(
            children: [
              SearchField(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceMd,
                    vertical: AppDimensions.spaceXs,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Posted total of this list',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        const MoneyFormatter().format(state.postedTotal!),
                        key: const Key('expenses_posted_total'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
              Expanded(child: _body(context, state)),
            ],
          ),
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
              key: Key('expense_${item.id}'),
              onTap: () => _open(
                context,
                RouteNames.expenseDetail,
                params: {'id': item.id},
              ),
              title: Text(item.description),
              subtitle: Text(
                [
                  formatExpenseDate(item.expenseDate),
                  item.categoryName,
                  if (item.payee != null) item.payee!,
                  item.displayNumber,
                ].join(' · '),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatter.format(item.total),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  DocumentStatusChip(status: item.status),
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              key: const Key('filter_all'),
              label: const Text('All'),
              selected: selected == null,
              onSelected: (_) => bloc.add(const ExpensesStatusChanged(null)),
            ),
          ),
          for (final status in _statuses)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                key: Key('filter_${status.dbName}'),
                label: Text(status.label),
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
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spaceMd),
      child: Row(
        children: [
          Expanded(
            child: DropdownButton<String?>(
              key: const Key('filter_category'),
              isExpanded: true,
              value: state.filter.categoryId,
              hint: const Text('All categories'),
              items: [
                const DropdownMenuItem<String?>(child: Text('All categories')),
                for (final category in state.categories)
                  DropdownMenuItem<String?>(
                    value: category.id,
                    child: Text(
                      category.isArchived
                          ? '${category.name} (archived)'
                          : category.name,
                    ),
                  ),
              ],
              onChanged: (value) => bloc.add(ExpensesCategoryChanged(value)),
            ),
          ),
          const SizedBox(width: AppDimensions.spaceSm),
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
