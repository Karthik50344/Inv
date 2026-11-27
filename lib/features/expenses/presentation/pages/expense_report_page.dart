import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/services/expense_period.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_report_cubit.dart';
import 'package:inventrix/features/expenses/presentation/widgets/expense_formatters.dart';
import 'package:inventrix/shared/presentation/snackbar.dart';
import 'package:inventrix/shared/presentation/view_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

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
    final picked = await showAppDateRangePicker(
      context,
      first: DateTime(2000),
      last: DateTime(now.year + 1, 12, 31),
      initial: from != null && to != null
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
          appBar: const AppAppBar(title: 'Expense report'),
          body: AppContentWidth(child: Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s8,
                  ),
                  children: [
                    for (final period in ExpensePeriod.values)
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.s8),
                        child: AppChip(
                          key: Key('period_${period.name}'),
                          label: period.label,
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s16,
                  AppSpacing.s4,
                  AppSpacing.s16,
                  AppSpacing.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.from == null || state.to == null
                          ? ''
                          : '${formatExpenseDate(state.from!)} – '
                                '${formatExpenseDate(state.to!)}',
                      key: const Key('report_range'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.textSecondary,
                      ),
                    ),
                    AppSpacing.gap8,
                    AppDropdown<String?>(
                      key: const Key('report_category'),
                      value: state.categoryId,
                      hint: 'All categories',
                      prefixIcon: Icons.category_outlined,
                      items: [
                        const AppDropdownItem<String?>(
                          value: null,
                          label: 'All categories',
                        ),
                        for (final c in state.categories)
                          AppDropdownItem<String?>(
                            value: c.id,
                            label: c.isArchived
                                ? '${c.name} (archived)'
                                : c.name,
                          ),
                      ],
                      onChanged: cubit.setCategory,
                    ),
                  ],
                ),
              ),
              Expanded(child: _body(context, state)),
            ],
          )),
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
    final tokens = context.appColors;
    final whole = report.total.minorUnits;
    return ListView(
      padding: AppSpacing.page,
      children: [
        AppStatCard(
          label: 'Total spent',
          value: formatter.format(report.total),
          icon: Icons.account_balance_wallet_outlined,
          tone: AppTone.warning,
          subtitle: '${report.count} expense${report.count == 1 ? '' : 's'}',
          key: const Key('report_total'),
        ),
        AppSpacing.gap12,
        AppCard(
          child: Column(
            children: [
              _line(
                context,
                'Expenses',
                '${report.count}',
                key: const Key('report_count'),
              ),
              _line(context, 'Net', formatter.format(report.net)),
              _line(context, 'Tax', formatter.format(report.tax)),
            ],
          ),
        ),
        if (report.otherCurrencyCount > 0) ...[
          AppSpacing.gap12,
          AppCard(
            tone: AppTone.warning,
            child: Text(
              '${report.otherCurrencyCount} posted expense'
              '${report.otherCurrencyCount == 1 ? ' is' : 's are'} in '
              'another currency and not included in these totals.',
              key: const Key('report_other_currency'),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
        const AppSectionHeader(
          title: 'By category',
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s24,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
        ),
        for (final item in report.byCategory)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: AppCard(
              key: Key('report_category_${item.categoryId}'),
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
                        style: context.appText.financialSmall,
                      ),
                    ],
                  ),
                  AppSpacing.gap8,
                  // Display only: the bar is a drawing, the figures above
                  // and below are exact integer values.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      minHeight: 6,
                      value: whole <= 0 ? 0 : item.total.minorUnits / whole,
                      backgroundColor: tokens.divider,
                    ),
                  ),
                  AppSpacing.gap8,
                  Text(
                    '${item.count} expense${item.count == 1 ? '' : 's'} · '
                    '${formatShare(item.total.minorUnits, whole)} of total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        AppSpacing.gap8,
        Text(
          'Only posted expenses are counted, by their expense date, at the '
          'amount paid (tax included). Drafts, cancelled and voided '
          'expenses are left out.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    Key? key,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          Text(value, key: key, style: context.appText.financialSmall),
        ],
      ),
    );
  }
}
