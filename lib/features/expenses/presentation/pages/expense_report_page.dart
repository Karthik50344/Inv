import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/services/expense_period.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_report_cubit.dart';
import 'package:inventrix/features/expenses/presentation/widgets/expense_formatters.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';
import 'package:inventrix/shared/presentation/widgets/error_state.dart';
import 'package:inventrix/shared/presentation/widgets/loading_indicator.dart';

/// Posted expenses by category for a period.
class ExpenseReportPage extends StatelessWidget {
  /// Creates the page. Provide an [ExpenseReportCubit] above it.
  const ExpenseReportPage({super.key});

  Future<void> _pickRange(
    BuildContext context,
    ExpenseReportState state,
  ) async {
    final cubit = context.read<ExpenseReportCubit>();
    final now = DateTime.now();
    final from = state.from;
    final to = state.to;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked != null) {
      await cubit.setCustomRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpenseReportCubit, ExpenseReportState>(
      listenWhen: (previous, current) =>
          current.message != null &&
          current.message != previous.message &&
          current.status != ViewStatus.failure,
      listener: (context, state) => showAppMessage(context, state.message!),
      builder: (context, state) {
        final cubit = context.read<ExpenseReportCubit>();
        return Scaffold(
          appBar: AppBar(title: const Text('Expense report')),
          body: Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  children: [
                    for (final period in ExpensePeriod.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          key: Key('period_${period.name}'),
                          label: Text(period.label),
                          selected: state.period == period,
                          onSelected: (_) => period == ExpensePeriod.custom
                              ? _pickRange(context, state)
                              : cubit.setPeriod(period),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spaceMd,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.from == null || state.to == null
                            ? ''
                            : '${formatExpenseDate(state.from!)} – '
                                  '${formatExpenseDate(state.to!)}',
                        key: const Key('report_range'),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    DropdownButton<String?>(
                      key: const Key('report_category'),
                      value: state.categoryId,
                      hint: const Text('All categories'),
                      items: [
                        const DropdownMenuItem<String?>(
                          child: Text('All categories'),
                        ),
                        for (final c in state.categories)
                          DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(
                              c.isArchived ? '${c.name} (archived)' : c.name,
                            ),
                          ),
                      ],
                      onChanged: cubit.setCategory,
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

  Widget _body(BuildContext context, ExpenseReportState state) {
    final cubit = context.read<ExpenseReportCubit>();
    switch (state.status) {
      case ViewStatus.initial:
      case ViewStatus.loading:
        return const LoadingIndicator();
      case ViewStatus.failure:
        return ErrorState(
          message: state.message ?? 'Could not build the report.',
          onRetry: cubit.refresh,
        );
      case ViewStatus.empty:
        return const EmptyState(
          icon: Icons.bar_chart_outlined,
          title: 'No expenses in this period',
          message: 'Only posted expenses are counted.',
        );
      case ViewStatus.loaded:
        return _Report(report: state.report!);
    }
  }
}

class _Report extends StatelessWidget {
  const _Report({required this.report});

  final ExpenseReport report;

  @override
  Widget build(BuildContext context) {
    const formatter = MoneyFormatter();
    final theme = Theme.of(context);
    final whole = report.total.minorUnits;
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spaceMd),
            child: Column(
              children: [
                _line(
                  theme,
                  'Expenses',
                  '${report.count}',
                  key: const Key('report_count'),
                ),
                _line(theme, 'Net', formatter.format(report.net)),
                _line(theme, 'Tax', formatter.format(report.tax)),
                const Divider(),
                _line(
                  theme,
                  'Total spent',
                  formatter.format(report.total),
                  strong: true,
                  key: const Key('report_total'),
                ),
              ],
            ),
          ),
        ),
        if (report.otherCurrencyCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spaceSm),
            child: Text(
              '${report.otherCurrencyCount} posted expense'
              '${report.otherCurrencyCount == 1 ? ' is' : 's are'} in '
              'another currency and not included in these totals.',
              key: const Key('report_other_currency'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: AppDimensions.spaceMd),
        Text('By category', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppDimensions.spaceSm),
        for (final item in report.byCategory)
          Card(
            key: Key('report_category_${item.categoryId}'),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.categoryName,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      Text(
                        formatter.format(item.total),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spaceXs),
                  // Display only: the bar is a drawing, the figures above
                  // and below are exact integer values.
                  LinearProgressIndicator(
                    value: whole <= 0 ? 0 : item.total.minorUnits / whole,
                  ),
                  const SizedBox(height: AppDimensions.spaceXs),
                  Text(
                    '${item.count} expense${item.count == 1 ? '' : 's'} · '
                    '${formatShare(item.total.minorUnits, whole)} of total',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppDimensions.spaceSm),
        Text(
          'Only posted expenses are counted, by their expense date, at the '
          'amount paid (tax included). Drafts, cancelled and voided '
          'expenses are left out.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _line(
    ThemeData theme,
    String label,
    String value, {
    bool strong = false,
    Key? key,
  }) {
    final style = strong
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, key: key, style: style),
        ],
      ),
    );
  }
}
