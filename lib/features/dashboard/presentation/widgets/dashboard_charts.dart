import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/widgets/app_card.dart';
import 'package:inventrix/shared/presentation/widgets/chart_style.dart';

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
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        0,
        AppSpacing.s16,
        AppSpacing.s12,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            if (subtitle != null)
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            AppSpacing.gap16,
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
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
    child: Row(
      children: [
        Icon(
          Icons.insights_outlined,
          size: 18,
          color: context.appColors.textDisabled,
        ),
        AppSpacing.hGap8,
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
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
    final tokens = context.appColors;
    final labelStyle = ChartStyle.axisText(context);
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
                  FlLine(color: tokens.divider, strokeWidth: 1),
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
                getTooltipColor: (_) => ChartStyle.tooltipColor(context),
                getTooltipItems: (spots) => [
                  for (final spot in spots)
                    LineTooltipItem(
                      '${chart.labels[spot.x.toInt()]}\n'
                      '${_money.format(Money.fromMinor(chart.series[spot.barIndex].values[spot.x.toInt()], currencyCode: chart.currencyCode, decimalPlaces: chart.decimalPlaces))}',
                      ChartStyle.tooltipText(context),
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
                  color: tokens.chartColor(s),
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: tokens.chartColor(s).withValues(alpha: 0.14),
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
    this.colors,
    super.key,
  });

  /// The slices.
  final List<DonutSlice> slices;

  /// Big text in the middle (for example a total).
  final String? centerText;

  /// Small text under [centerText].
  final String? centerLabel;

  /// Fixed colour per slice position (for example green / amber / red for
  /// stock health). Defaults to the chart palette.
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appColors;
    // Keep each slice's original position so a hidden zero slice does not
    // shift the colours of the others.
    final shown = <MapEntry<int, DonutSlice>>[
      for (var i = 0; i < slices.length; i++)
        if (slices[i].value > 0) MapEntry(i, slices[i]),
    ];
    final total = shown.fold<int>(0, (a, e) => a + e.value.value);
    if (shown.isEmpty) {
      return const NoChartData();
    }
    Color colorAt(int index) =>
        colors != null && index < colors!.length
        ? colors![index]
        : tokens.chartColor(index);
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
                  sectionsSpace: 3,
                  centerSpaceRadius: 46,
                  sections: [
                    for (final e in shown)
                      PieChartSectionData(
                        value: e.value.value.toDouble(),
                        color: colorAt(e.key),
                        radius: 20,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              if (centerText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          centerText!,
                          style: context.appText.financialSmall,
                        ),
                      ),
                      if (centerLabel != null)
                        Text(
                          centerLabel!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        AppSpacing.hGap16,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colorAt(e.key),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      AppSpacing.hGap8,
                      Expanded(
                        child: Text(
                          e.value.label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      AppSpacing.hGap8,
                      Text(
                        '${e.value.text} · ${(e.value.value * 100 / total).round()}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.textSecondary,
                        ),
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
  /// Creates a row. [value] may be negative (drawn in the danger colour).
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
    final tokens = context.appColors;
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
                      style: context.appText.financialSmall.copyWith(
                        color: bars[i].value < 0
                            ? tokens.danger.solid
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: bars[i].value.abs() / maxAbs,
                    minHeight: 8,
                    color: bars[i].value < 0
                        ? tokens.danger.solid
                        : tokens.chartColor(i),
                    backgroundColor: tokens.divider,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
