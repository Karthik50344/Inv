import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/entities/report_period.dart';
import 'package:inventrix/features/reports/domain/services/finance_report_documents.dart';
import 'package:inventrix/features/reports/domain/services/profit_calculator.dart';
import 'package:inventrix/features/reports/domain/services/register_report_document.dart';
import 'package:inventrix/features/reports/domain/services/report_csv.dart';
import 'package:inventrix/features/reports/domain/services/time_buckets.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../../support/report_fakes.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

void main() {
  group('DateRange', () {
    test('normalises to dates and counts inclusive days', () {
      final r = DateRange(
        from: DateTime.utc(2026, 11, 1, 15),
        to: d(2026, 11, 15),
      );
      expect(r.from, d(2026, 11, 1));
      expect(r.dayCount, 15);
      expect(r.contains(DateTime.utc(2026, 11, 15, 23)), isTrue);
      expect(r.contains(d(2026, 11, 16)), isFalse);
    });
    test('rejects an inverted range', () {
      expect(
        () => DateRange(from: d(2026, 11, 2), to: d(2026, 11, 1)),
        throwsArgumentError,
      );
    });
  });

  group('ReportPeriod', () {
    final today = d(2026, 11, 15);
    test('presets', () {
      expect(
        ReportPeriod.today.rangeFor(today),
        DateRange(from: today, to: today),
      );
      expect(ReportPeriod.last7Days.rangeFor(today)!.from, d(2026, 11, 9));
      expect(ReportPeriod.thisMonth.rangeFor(today)!.from, d(2026, 11, 1));
      expect(ReportPeriod.last30Days.rangeFor(today)!.from, d(2026, 10, 17));
      expect(ReportPeriod.thisYear.rangeFor(today)!.from, d(2026, 1, 1));
      expect(ReportPeriod.custom.rangeFor(today), isNull);
    });
    test('last month crosses the year boundary', () {
      final r = ReportPeriod.lastMonth.rangeFor(d(2027, 1, 10))!;
      expect(r.from, d(2026, 12, 1));
      expect(r.to, d(2026, 12, 31));
    });
    test('last month handles a 28-day February', () {
      expect(
        ReportPeriod.lastMonth.rangeFor(d(2027, 3, 5))!.to,
        d(2027, 2, 28),
      );
    });
  });

  group('ReportKind', () {
    test('slugs round-trip', () {
      for (final k in ReportKind.values) {
        expect(ReportKind.fromSlug(k.slug), k);
      }
      expect(ReportKind.fromSlug('nope'), isNull);
    });
  });

  group('TimeBuckets', () {
    test('short ranges are daily', () {
      final b = TimeBuckets.build(
        DateRange(from: d(2026, 11, 1), to: d(2026, 11, 3)),
      );
      expect(b.map((e) => e.label).toList(), ['1 Nov', '2 Nov', '3 Nov']);
    });
    test('31 days is still daily, 32 switches to months', () {
      expect(
        TimeBuckets.build(DateRange(from: d(2026, 10, 1), to: d(2026, 10, 31))),
        hasLength(31),
      );
      final m = TimeBuckets.build(
        DateRange(from: d(2026, 10, 1), to: d(2026, 11, 1)),
      );
      expect(m.map((e) => e.label).toList(), ['Oct 26', 'Nov 26']);
    });
    test('monthly buckets clip the first and last month', () {
      final b = TimeBuckets.build(
        DateRange(from: d(2026, 1, 15), to: d(2026, 3, 10)),
      );
      expect(b, hasLength(3));
      expect(b.first.from, d(2026, 1, 15));
      expect(b.first.to, d(2026, 1, 31));
      expect(b.last.to, d(2026, 3, 10));
    });
    test('sum puts amounts into the right bucket and ignores outsiders', () {
      final b = TimeBuckets.build(
        DateRange(from: d(2026, 1, 1), to: d(2026, 3, 31)),
      );
      final sums = TimeBuckets.sum(b, [
        DatedAmount(d(2026, 1, 5), inr(100)),
        DatedAmount(d(2026, 1, 31), inr(50)),
        DatedAmount(d(2026, 3, 1), inr(7)),
        DatedAmount(d(2025, 12, 31), inr(999)),
      ]);
      expect(sums, [150, 0, 7]);
    });
    test('net subtracts returns per bucket', () {
      final b = TimeBuckets.build(
        DateRange(from: d(2026, 11, 1), to: d(2026, 11, 2)),
      );
      final net = TimeBuckets.net(
        b,
        DailySeries(
          documents: [DatedAmount(d(2026, 11, 1), inr(1000))],
          returns: [
            DatedAmount(d(2026, 11, 1), inr(300)),
            DatedAmount(d(2026, 11, 2), inr(100)),
          ],
        ),
      );
      expect(net, [700, -100]);
    });
    test('cumulative gives the running total', () {
      expect(TimeBuckets.cumulative([100, 50, -30, 0]), [100, 150, 120, 120]);
      expect(TimeBuckets.cumulative([]), isEmpty);
    });
    test('chart bars add up to the document totals', () {
      final range = DateRange(from: d(2026, 1, 1), to: d(2026, 12, 31));
      final series = DailySeries(
        documents: [
          for (var m = 1; m <= 12; m++)
            DatedAmount(d(2026, m, 15), inr(m * 1000)),
        ],
        returns: [DatedAmount(d(2026, 6, 1), inr(2500))],
      );
      final total = TimeBuckets.net(
        TimeBuckets.build(range),
        series,
      ).fold<int>(0, (a, b) => a + b);
      expect(total, 78000 - 2500);
    });
  });

  group('ProfitFigures', () {
    test('gross profit and operating result', () {
      final p = ProfitFigures(
        netSales: inr(100000),
        costOfGoodsSold: inr(60000),
        expenses: inr(15000),
      );
      expect(p.grossProfit, inr(40000));
      expect(p.operatingResult, inr(25000));
      expect(p.grossMarginBasisPoints, 4000);
      expect(p.operatingMarginBasisPoints, 2500);
    });
    test('a loss is negative', () {
      final p = ProfitFigures(
        netSales: inr(1000),
        costOfGoodsSold: inr(900),
        expenses: inr(500),
      );
      expect(p.operatingResult, inr(-400));
      expect(p.operatingMarginBasisPoints, -4000);
    });
    test('no sales means no margin', () {
      final p = ProfitFigures(
        netSales: inr(0),
        costOfGoodsSold: inr(0),
        expenses: inr(10),
      );
      expect(p.grossMarginBasisPoints, isNull);
      expect(p.operatingResult, inr(-10));
    });
    test('margin rounds half away from zero', () {
      final p = ProfitFigures(
        netSales: inr(3),
        costOfGoodsSold: inr(2),
        expenses: inr(0),
      );
      expect(p.grossMarginBasisPoints, 3333);
    });
  });

  group('figures', () {
    test('net after returns', () {
      final f = figures(
        count: 2,
        net: 1500,
        tax: 270,
        returnsCount: 1,
        returnsNet: 200,
        returnsTax: 36,
      );
      expect(f.netAfterReturns, inr(1300));
      expect(f.totalAfterReturns, inr(1770 - 236));
      expect(f.isEmpty, isFalse);
      expect(figures().isEmpty, isTrue);
    });
    test('product figures: net quantity, profit, margin', () {
      final p = ProductFigures(
        productId: 'a',
        name: 'W',
        sku: 'W1',
        unitSymbol: 'pcs',
        unitDecimalPlaces: 0,
        quantitySold: const Quantity.fromMilli(2000),
        quantityReturned: const Quantity.fromMilli(500),
        revenue: inr(1000),
        returnedRevenue: inr(200),
        cost: inr(1080),
      );
      expect(p.netQuantity, const Quantity.fromMilli(1500));
      expect(p.netRevenue, inr(800));
      expect(p.grossProfit, inr(-280));
      expect(p.marginBasisPoints, -3500);
      final none = ProductFigures(
        productId: 'b',
        name: 'G',
        sku: 'G',
        unitSymbol: 'kg',
        unitDecimalPlaces: 3,
        quantitySold: Quantity.zero,
        quantityReturned: const Quantity.fromMilli(300),
        revenue: inr(0),
        returnedRevenue: inr(100),
        cost: inr(0),
      );
      expect(none.marginBasisPoints, isNull);
    });
    test('cash totals', () {
      final c = CashFigures(
        customerPayments: inr(1300),
        customerRefunds: inr(50),
        supplierPayments: inr(250),
        supplierRefunds: inr(20),
        salesReturnRefunds: inr(236),
        purchaseReturnRefunds: inr(100),
        entryCount: 7,
        byMethod: const [],
      );
      expect(c.cashIn, inr(1420));
      expect(c.cashOut, inr(536));
      expect(c.net, inr(884));
    });
  });

  group('register document', () {
    ReportDocument build({int other = 0, int rows = 1}) =>
        RegisterReportDocument.build(
          kind: ReportKind.sales,
          filter: ReportFilter(
            range: DateRange(from: d(2026, 11, 1), to: d(2026, 11, 2)),
          ),
          generatedAt: DateTime.utc(2026, 11, 15, 9),
          scope: const ['Customer: Acme'],
          figures: figures(
            count: 3,
            net: 1500,
            tax: 270,
            returnsCount: 1,
            returnsNet: 200,
            returnsTax: 36,
            other: other,
          ),
          rows: [
            for (var i = 0; i < rows; i++)
              DocumentRow(
                id: 'i$i',
                number: 'INV-00000$i',
                date: d(2026, 11, 1),
                partyName: 'Acme',
                net: inr(1000),
                tax: inr(180),
                total: inr(1180),
              ),
          ],
          series: DailySeries(
            documents: [DatedAmount(d(2026, 11, 1), inr(1500))],
            returns: [DatedAmount(d(2026, 11, 2), inr(200))],
          ),
        );
    test('metrics, chart and table agree', () {
      final doc = build();
      final net =
          doc.metrics.firstWhere((m) => m.label == 'Net sales').value
              as MoneyCell;
      expect(net.money, inr(1300));
      expect(doc.charts.single.series.single.values, [1500, -200]);
      expect(
        doc.charts.single.series.single.values.fold<int>(0, (a, b) => a + b),
        net.money.minorUnits,
      );
      expect(doc.tables.single.totalRowCount, 3);
      expect(doc.tables.single.isTruncated, isTrue);
      expect(doc.periodText, '2026-11-01 to 2026-11-02');
    });
    test('mentions other currencies only when present', () {
      expect(build().notes.any((n) => n.contains('another currency')), isFalse);
      expect(build(other: 2).notes.any((n) => n.contains('2 record')), isTrue);
    });
  });

  group('finance documents', () {
    final filter = ReportFilter(
      range: DateRange(from: d(2026, 11, 1), to: d(2026, 11, 15)),
    );
    test('profitability lines tie out', () {
      final profit = ProfitFigures(
        netSales: inr(1300),
        costOfGoodsSold: inr(1380),
        expenses: inr(100),
      );
      final doc = FinanceReportDocuments.profitability(
        filter: filter,
        generatedAt: DateTime.utc(2026, 11, 15),
        sales: figures(count: 2, net: 1500, returnsNet: 200),
        profit: profit,
        expenseCount: 2,
      );
      final rows = doc.tables.single.rows;
      expect(rows, hasLength(7));
      expect((rows[2][1] as MoneyCell).money, inr(1300));
      expect((rows[4][1] as MoneyCell).money, inr(-80));
      expect((rows[6][1] as MoneyCell).money, inr(-180));
      expect(
        doc.notes.any((n) => n.contains('Purchases are not an expense')),
        isTrue,
      );
    });
    test('payments keep cash separate from revenue', () {
      final doc = FinanceReportDocuments.payments(
        filter: filter,
        generatedAt: DateTime.utc(2026, 11, 15),
        scope: const [],
        cash: CashFigures.empty(inr(0)),
      );
      expect(doc.notes.first, contains('Cash is not revenue'));
      expect(doc.tables, hasLength(2));
    });
  });

  group('CSV', () {
    ReportDocument doc(List<ReportCell> row, {String title = 'T'}) =>
        ReportDocument(
          kind: 'x',
          title: title,
          generatedAt: DateTime.utc(2026, 11, 15, 9),
          metrics: [ReportMetric('Total', MoneyCell(inr(-12345)))],
          tables: [
            ReportTable(
              title: 'Rows',
              columns: const [ReportColumn('A'), ReportColumn('B')],
              rows: [row],
            ),
          ],
        );
    test('numbers are plain and negatives are not neutralised', () {
      final csv = ReportCsv.encode(
        doc([
          MoneyCell(inr(-5)),
          const QuantityCell(Quantity.fromMilli(1500), decimals: 1),
        ]),
        withBom: false,
      );
      expect(csv, contains('Total,-123.45\r\n'));
      expect(csv, contains('-0.05,1.5\r\n'));
    });
    test('quotes commas, quotes and newlines', () {
      final csv = ReportCsv.encode(
        doc([const TextCell('a,b'), const TextCell('say "hi"\nnow')]),
        withBom: false,
      );
      expect(csv, contains('"a,b","say ""hi""\nnow"'));
    });
    test('neutralises formula injection in text only', () {
      final csv = ReportCsv.encode(
        doc([const TextCell('=SUM(A1)'), const TextCell('@cmd')]),
        withBom: false,
      );
      expect(csv, contains("'=SUM(A1),'@cmd"));
    });
    test('dates, counts, percents and empty cells', () {
      final csv = ReportCsv.encode(
        doc([DateCell(d(2026, 3, 9)), const PercentCell(-1234)]),
        withBom: false,
      );
      expect(csv, contains('2026-03-09,-12.34'));
      expect(ReportCsv.cellText(const EmptyCell()), '');
      expect(ReportCsv.cellText(const CountCell(7)), '7');
      expect(ReportCsv.percentText(5), '0.05');
    });
    test('BOM and truncation note', () {
      final base = doc([const TextCell('x'), const TextCell('y')]);
      expect(ReportCsv.encode(base).startsWith(ReportCsv.bom), isTrue);
      final cut = ReportDocument(
        kind: 'x',
        title: 'T',
        generatedAt: DateTime.utc(2026),
        tables: [
          const ReportTable(
            title: 'R',
            columns: [ReportColumn('A')],
            rows: [
              [TextCell('x')],
            ],
            totalRowCount: 9,
          ),
        ],
      );
      expect(
        ReportCsv.encode(cut, withBom: false),
        contains('Only 1 of 9 rows are included.'),
      );
    });
  });
}
