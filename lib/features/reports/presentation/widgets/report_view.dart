import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/presentation/widgets/report_formatters.dart';
import 'package:inventrix/features/reports/presentation/widgets/trend_bar_chart.dart';

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
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.spaceMd),
      children: [
        if (document.scope.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spaceSm),
            child: Text(
              document.scope.join(' · '),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        if (document.metrics.isNotEmpty) _Metrics(metrics: document.metrics),
        if (emptyMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.spaceMd,
            ),
            child: Text(
              emptyMessage!,
              key: const Key('report_empty_message'),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
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
        const gap = AppDimensions.spaceSm;
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
    final theme = Theme.of(context);
    final negative = ReportFormatters.isNegative(metric.value);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metric.label, style: theme.textTheme.labelMedium),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                ReportFormatters.cell(metric.value),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: negative ? theme.colorScheme.error : null,
                ),
              ),
            ),
            if (metric.hint != null)
              Text(metric.hint!, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.chart});

  final ReportChart chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chart.title, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppDimensions.spaceSm),
            if (chart.isFlat)
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.spaceMd,
                ),
                child: Text(
                  'Nothing to chart in this period.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else ...[
              Wrap(
                spacing: AppDimensions.spaceMd,
                children: TrendBarChart.legend(context, chart),
              ),
              const SizedBox(height: AppDimensions.spaceSm),
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
    final shown = table.rows.take(ReportView.screenRowLimit).toList();
    final total = table.totalRowCount ?? table.rows.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spaceMd,
              ),
              child: Text(table.title, style: theme.textTheme.titleSmall),
            ),
            if (table.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppDimensions.spaceMd),
                child: Text('No rows.', style: theme.textTheme.bodySmall),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  columns: [
                    for (final c in table.columns)
                      DataColumn(label: Text(c.label), numeric: c.numeric),
                  ],
                  rows: [
                    for (final row in shown)
                      DataRow(
                        cells: [
                          for (final cell in row)
                            DataCell(
                              Text(
                                ReportFormatters.cell(cell),
                                style: ReportFormatters.isNegative(cell)
                                    ? TextStyle(color: theme.colorScheme.error)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            if (shown.length < total)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spaceMd,
                  AppDimensions.spaceSm,
                  AppDimensions.spaceMd,
                  0,
                ),
                child: Text(
                  'Showing ${shown.length} of $total rows. Export to CSV for '
                  'the full list.',
                  key: const Key('table_truncated'),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.notes});

  final List<String> notes;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        key: const Key('report_notes'),
        title: const Text('How this is calculated'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('•  $note'),
            ),
        ],
      ),
    );
  }
}
