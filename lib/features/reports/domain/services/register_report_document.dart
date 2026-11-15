import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/services/report_text.dart';
import 'package:inventrix/features/reports/domain/services/time_buckets.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Builds the sales and the purchase report: the same layout for both.
abstract final class RegisterReportDocument {
  /// Builds the report of [kind] (`sales` or `purchases`).
  static ReportDocument build({
    required ReportKind kind,
    required ReportFilter filter,
    required DateTime generatedAt,
    required List<String> scope,
    required DocumentFigures figures,
    required List<DocumentRow> rows,
    required DailySeries series,
  }) {
    assert(
      kind == ReportKind.sales || kind == ReportKind.purchases,
      'Only sales and purchases use this layout.',
    );
    final isSales = kind == ReportKind.sales;
    final noun = isSales ? 'Sales' : 'Purchases';
    final party = isSales ? 'Customer' : 'Supplier';
    final netLabel = isSales ? 'Net sales' : 'Net purchases';
    final buckets = TimeBuckets.build(filter.range);
    final netByBucket = TimeBuckets.net(buckets, series);

    final currencyCode = figures.net.currencyCode;
    final decimals = figures.net.decimalPlaces;
    final otherNote = ReportText.otherCurrencyNote(figures.otherCurrencyCount);

    return ReportDocument(
      kind: kind.name,
      title: kind.title,
      generatedAt: generatedAt,
      periodText: ReportText.period(filter.range),
      scope: scope,
      metrics: [
        ReportMetric(
          isSales ? 'Invoices' : 'Purchase invoices',
          CountCell(figures.count),
        ),
        ReportMetric('$noun (excl. tax)', MoneyCell(figures.net)),
        ReportMetric(
          'Returns (excl. tax)',
          MoneyCell(figures.returnsNet),
          hint: '${figures.returnsCount} return(s)',
        ),
        ReportMetric(netLabel, MoneyCell(figures.netAfterReturns)),
        ReportMetric(
          'Tax (after returns)',
          MoneyCell(figures.tax - figures.returnsTax),
        ),
        ReportMetric(
          'Total incl. tax (after returns)',
          MoneyCell(figures.totalAfterReturns),
        ),
      ],
      charts: [
        ReportChart(
          title: '$netLabel (excl. tax)',
          labels: [for (final b in buckets) b.label],
          series: [ChartSeries(netLabel, netByBucket)],
          currencyCode: currencyCode,
          decimalPlaces: decimals,
        ),
      ],
      tables: [
        ReportTable(
          title: isSales ? 'Sales invoices' : 'Purchase invoices',
          columns: [
            const ReportColumn('Number'),
            const ReportColumn('Date'),
            ReportColumn(party),
            const ReportColumn('Net', numeric: true),
            const ReportColumn('Tax', numeric: true),
            const ReportColumn('Total', numeric: true),
          ],
          rows: [
            for (final r in rows)
              [
                TextCell(r.number),
                DateCell(r.date),
                TextCell(r.partyName),
                MoneyCell(r.net),
                MoneyCell(r.tax),
                MoneyCell(r.total),
              ],
          ],
          totalRowCount: figures.count,
        ),
      ],
      notes: [
        'Only posted documents count; drafts, cancelled and voided '
            'documents are left out.',
        'Documents are counted on their document date, returns on their '
            'return date.',
        '$netLabel is $noun minus returns, excluding tax.',
        if (!isSales)
          'Purchases are stock bought, not an expense: they become cost '
              'only when the goods are sold.',
        ?otherNote,
      ],
    );
  }

  /// Sum of a list of money values in [zero]'s currency.
  static Money sumOf(Iterable<Money> values, Money zero) =>
      values.fold(zero, (a, b) => a + b);
}
