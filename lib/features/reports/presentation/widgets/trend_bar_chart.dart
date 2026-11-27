import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/widgets/chart_style.dart';

/// A grouped bar chart of amounts over time.
///
/// Values arrive in minor units and are converted to `double` only to place
/// the bars; every figure shown as text is formatted from exact [Money].
class TrendBarChart extends StatelessWidget {
  /// Creates the chart.
  const TrendBarChart({required this.chart, this.height = 190, super.key});

  /// The data.
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

  String _text(int minor) => _money.format(
    Money.fromMinor(
      minor,
      currencyCode: chart.currencyCode,
      decimalPlaces: chart.decimalPlaces,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.appColors;
    final labelStyle = ChartStyle.axisText(context);
    final step = (chart.labels.length / 6).ceil().clamp(1, 1000);
    final barWidth = chart.labels.length > 16 ? 5.0 : 9.0;

    return Semantics(
      label: chart.title,
      child: SizedBox(
        height: height,
        child: BarChart(
          BarChartData(
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
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => ChartStyle.tooltipColor(context),
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final series = chart.series[rodIndex];
                  return BarTooltipItem(
                    '${chart.labels[groupIndex]}\n'
                    '${series.name}: ${_text(series.values[groupIndex])}',
                    ChartStyle.tooltipText(context),
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < chart.labels.length; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    for (var s = 0; s < chart.series.length; s++)
                      BarChartRodData(
                        toY: _scale(chart.series[s].values[i]),
                        width: barWidth,
                        color: tokens.chartColor(s),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Legend entries for [chart] (colours match the bars).
  static List<Widget> legend(BuildContext context, ReportChart chart) {
    final tokens = context.appColors;
    return [
      for (var s = 0; s < chart.series.length; s++)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: tokens.chartColor(s),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              chart.series[s].name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
          ],
        ),
    ];
  }
}
