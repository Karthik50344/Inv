import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Colours used by the dashboard charts, taken from the theme.
List<Color> chartPalette(ColorScheme scheme) => [
  scheme.primary,
  scheme.tertiary,
  scheme.secondary,
  scheme.error,
  scheme.primaryContainer,
  scheme.outline,
];

/// A card with a title, an optional subtitle and a chart body.
class ChartCard extends StatelessWidget {
  /// Creates the card.
  const ChartCard({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });

  /// Heading.
  final String title;

  /// Smaller text under the heading.
  final String? subtitle;

  /// The chart.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            if (subtitle != null)
              Text(subtitle!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Text shown instead of a chart that has no data.
class NoChartData extends StatelessWidget {
  /// Creates the message.
  const NoChartData({
    this.message = 'Nothing to show for this period.',
    super.key,
  });

  /// What to say.
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(message, style: Theme.of(context).textTheme.bodySmall),
  );
}

/// A line chart with a soft fill under the line.
///
/// Values arrive in minor units; `double` is used only to place the points.
class TrendLineChart extends StatelessWidget {
  /// Creates the chart.
  const TrendLineChart({required this.chart, this.height = 180, super.key});

  /// The data (every series is drawn as a line).
  final ReportChart chart;

  /// Chart height.
  final double height;

  static const MoneyFormatter _money = MoneyFormatter();

  double _scale(int minor) {
    var factor = 1.0;
    for (var i = 0; i < chart.decimalPlaces; i++) {
      factor *= 10;
    }
    return minor / factor;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = chartPalette(scheme);
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    final step = (chart.labels.length / 6).ceil().clamp(1, 1000);
    return Semantics(
      label: chart.title,
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) =>
                  FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: const AxisTitles(),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= chart.labels.length || i % step != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(chart.labels[i], style: labelStyle),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${chart.labels[spot.x.toInt()]}\n'
                      '${_money.format(Money.fromMinor(chart.series[spot.barIndex].values[spot.x.toInt()], currencyCode: chart.currencyCode, decimalPlaces: chart.decimalPlaces))}',
                      TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              for (var s = 0; s < chart.series.length; s++)
                LineChartBarData(
                  spots: [
                    for (var i = 0; i < chart.labels.length; i++)
                      FlSpot(i.toDouble(), _scale(chart.series[s].values[i])),
                  ],
                  isCurved: true,
                  barWidth: 3,
                  color: colors[s % colors.length],
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: colors[s % colors.length].withValues(alpha: 0.15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One slice of a [DonutChart].
class DonutSlice {
  /// Creates a slice. [value] must not be negative.
  const DonutSlice(this.label, this.value, this.text);

  /// Name in the legend.
  final String label;

  /// Size of the slice (any positive unit; only ratios matter).
  final int value;

  /// Formatted amount for the legend.
  final String text;
}

/// A donut chart with a legend. Slices with no value are left out.
class DonutChart extends StatelessWidget {
  /// Creates the chart. [centerText] is drawn in the hole.
  const DonutChart({
    required this.slices,
    this.centerText,
    this.centerLabel,
    super.key,
  });

  /// The slices.
  final List<DonutSlice> slices;

  /// Big text in the middle (for example a total).
  final String? centerText;

  /// Small text under [centerText].
  final String? centerLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = chartPalette(theme.colorScheme);
    final shown = [
      for (final s in slices)
        if (s.value > 0) s,
    ];
    final total = shown.fold<int>(0, (a, s) => a + s.value);
    if (shown.isEmpty) {
      return const NoChartData();
    }
    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  sections: [
                    for (var i = 0; i < shown.length; i++)
                      PieChartSectionData(
                        value: shown[i].value.toDouble(),
                        color: colors[i % colors.length],
                        radius: 22,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              if (centerText != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centerText!, style: theme.textTheme.titleMedium),
                    if (centerLabel != null)
                      Text(centerLabel!, style: theme.textTheme.labelSmall),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < shown.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          shown[i].label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${shown[i].text} · ${(shown[i].value * 100 / total).round()}%',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One row of [RankedBars].
class RankedBar {
  /// Creates a row. [value] may be negative (drawn in the error colour).
  const RankedBar(this.label, this.value, this.text);

  /// Name.
  final String label;

  /// Size of the bar (any unit; compared with the other rows).
  final int value;

  /// Formatted amount shown at the end of the row.
  final String text;
}

/// Horizontal bars scaled to the largest absolute value.
class RankedBars extends StatelessWidget {
  /// Creates the bars.
  const RankedBars({required this.bars, super.key});

  /// The rows, drawn in the given order.
  final List<RankedBar> bars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = chartPalette(theme.colorScheme);
    var maxAbs = 0;
    for (final b in bars) {
      if (b.value.abs() > maxAbs) {
        maxAbs = b.value.abs();
      }
    }
    if (bars.isEmpty || maxAbs == 0) {
      return const NoChartData();
    }
    return Column(
      children: [
        for (var i = 0; i < bars.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bars[i].label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      bars[i].text,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: bars[i].value < 0
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: bars[i].value.abs() / maxAbs,
                    minHeight: 8,
                    color: bars[i].value < 0
                        ? theme.colorScheme.error
                        : colors[i % colors.length],
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
