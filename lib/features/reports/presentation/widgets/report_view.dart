import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/presentation/widgets/report_formatters.dart';
import 'package:inventrix/features/reports/presentation/widgets/trend_bar_chart.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// Draws any [ReportDocument]: headline figures, charts, tables and the
/// notes that explain how the figures were worked out.
class ReportView extends StatelessWidget {
  /// Creates the view. [emptyMessage] is shown under the figures when the
  /// report has no rows.
  const ReportView({required this.document, this.emptyMessage, super.key});

  /// The report to draw.
  final ReportDocument document;

  /// Text for a report without rows, or `null` to show nothing extra.
  final String? emptyMessage;

  /// Most rows drawn per table; the CSV export always has all of them.
  static const int screenRowLimit = 100;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    return ListView(
      physics: AppRefreshIndicator.physics,
      padding: AppSpacing.page,
      children: [
        if (document.scope.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Text(
              document.scope.join(' · '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
        if (document.metrics.isNotEmpty) _Metrics(metrics: document.metrics),
        if (emptyMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 40,
                  color: tokens.textSecondary,
                ),
                AppSpacing.gap8,
                Text(
                  emptyMessage!,
                  key: const Key('report_empty_message'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        for (final chart in document.charts) _ChartCard(chart: chart),
        for (final table in document.tables) _TableCard(table: table),
        if (document.notes.isNotEmpty) _Notes(notes: document.notes),
      ],
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.metrics});

  final List<ReportMetric> metrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 3 : 2;
        const gap = AppSpacing.s12;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final m in metrics) SizedBox(width: width, child: _Metric(m)),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.metric);

  final ReportMetric metric;

  @override
  Widget build(BuildContext context) {
    final negative = ReportFormatters.isNegative(metric.value);
    return AppStatCard(
      label: metric.label,
      value: ReportFormatters.cell(metric.value),
      subtitle: metric.hint,
      valueTone: negative ? AppTone.danger : null,
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.chart});

  final ReportChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chart.title, style: theme.textTheme.titleSmall),
            AppSpacing.gap12,
            if (chart.isFlat)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                child: Text(
                  'Nothing to chart in this period.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              )
            else ...[
              Wrap(
                spacing: AppSpacing.s16,
                runSpacing: AppSpacing.s4,
                children: TrendBarChart.legend(context, chart),
              ),
              AppSpacing.gap12,
              TrendBarChart(chart: chart),
            ],
          ],
        ),
      ),
    );
  }
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table});

  final ReportTable table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    final shown = table.rows.take(ReportView.screenRowLimit).toList();
    final total = table.totalRowCount ?? table.rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: table.title,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s4,
            AppSpacing.s24,
            AppSpacing.s4,
            AppSpacing.s8,
          ),
        ),
        AppDataTable(
          emptyMessage: 'No rows.',
          columns: [
            for (final c in table.columns)
              AppDataColumn(label: c.label, numeric: c.numeric),
          ],
          rows: [
            for (final row in shown)
              AppDataRow(
                cells: [
                  for (final cell in row)
                    Text(
                      ReportFormatters.cell(cell),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: ReportFormatters.isNegative(cell)
                            ? tokens.danger.solid
                            : null,
                      ),
                    ),
                ],
              ),
          ],
        ),
        if (shown.length < total)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s8),
            child: Text(
              'Showing ${shown.length} of $total rows. Export to CSV for '
              'the full list.',
              key: const Key('table_truncated'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s16),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('report_notes'),
            title: const Text('How this is calculated'),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              0,
              AppSpacing.s16,
              AppSpacing.s16,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final note in notes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '•  $note',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
