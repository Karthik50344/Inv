import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/dashboard/domain/usecases/get_dashboard.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/services/report_filter_options.dart';
import 'package:inventrix/features/reports/domain/usecases/build_report.dart';
import 'package:inventrix/features/reports/domain/usecases/export_report.dart';
import 'package:inventrix/features/reports/domain/usecases/get_profit_figures.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../../support/expense_fakes.dart';
import '../../support/fakes.dart';
import '../../support/inventory_fakes.dart';
import '../../support/payment_fakes.dart';
import '../../support/report_fakes.dart';

class StubExpenses extends FakeExpenseRepository {
  ExpenseReport? stub;
  Failure? reportFailure;

  @override
  Future<Result<ExpenseReport>> report(ExpenseReportFilter f) async =>
      reportFailure != null
      ? Result.failure(reportFailure!)
      : Result.success(stub ?? _expenseReport(f, 0, 0));
}

ExpenseReport _expenseReport(ExpenseReportFilter f, int net, int tax) =>
    ExpenseReport(
      filter: f,
      count: net == 0 ? 0 : 2,
      net: inr(net),
      tax: inr(tax),
      total: inr(net + tax),
      byCategory: const [],
    );

class ReportFixture {
  ReportFixture() {
    final c = pay.settings.config;
    inventory = FakeInventoryRepository(products, c, pay.clock);
    units = FakeUnitRepository(products);
    final options = ReportFilterOptions(
      products: products,
      parties: PartyDirectory(
        customers: pay.customers,
        suppliers: pay.suppliers,
      ),
    );
    profit = GetProfitFigures(reports: reports, expenses: expenses);
    build = BuildReport(
      reports: reports,
      expenses: expenses,
      profit: profit,
      inventory: inventory,
      units: units,
      balances: pay.balances,
      options: options,
      settings: pay.settings,
      clock: pay.clock,
    );
    dashboard = GetDashboard(
      reports: reports,
      expenses: expenses,
      inventory: inventory,
      balances: pay.balances,
      profit: profit,
      settings: pay.settings,
      clock: pay.clock,
    );
    exporter = FakeReportExporter();
    export = ExportReportCsv(exporter: exporter);
    this.options = options;
  }

  final PaymentFixture pay = PaymentFixture();
  final FakeReportRepository reports = FakeReportRepository();
  final StubExpenses expenses = StubExpenses();
  final FakeProductRepository products = FakeProductRepository();
  late final FakeInventoryRepository inventory;
  late final FakeUnitRepository units;
  late final GetProfitFigures profit;
  late final BuildReport build;
  late final GetDashboard dashboard;
  late final FakeReportExporter exporter;
  late final ExportReportCsv export;
  late final ReportFilterOptions options;

  final range = DateRange(
    from: DateTime.utc(2026, 11, 1),
    to: DateTime.utc(2026, 11, 15),
  );
  ReportFilter get filter => ReportFilter(range: range);
}

void main() {
  late ReportFixture f;
  setUp(() => f = ReportFixture());

  MoneyCell metric(ReportDocument d, String label) =>
      d.metrics.firstWhere((m) => m.label == label).value as MoneyCell;

  group('GetProfitFigures', () {
    test(
      'combines net sales after returns, ledger cost and net expenses',
      () async {
        f.reports.sales = figures(
          count: 2,
          net: 1500,
          tax: 270,
          returnsNet: 200,
        );
        f.reports.cogs = inr(1380);
        f.expenses.stub = _expenseReport(
          ExpenseReportFilter(from: f.range.from, to: f.range.to),
          100,
          18,
        );
        final p = (await f.profit(f.filter)).getOrThrow();
        expect(p.netSales, inr(1300));
        expect(p.costOfGoodsSold, inr(1380));
        expect(p.expenses, inr(100)); // tax excluded
        expect(p.operatingResult, inr(-180));
      },
    );
    test('passes a repository failure through', () async {
      f.reports.failure = const DatabaseFailure('boom');
      final r = await f.profit(f.filter);
      expect(r.failureOrNull, isA<DatabaseFailure>());
    });
    test('passes an expense failure through', () async {
      f.expenses.reportFailure = const DatabaseFailure('x');
      expect((await f.profit(f.filter)).isFailure, isTrue);
    });
  });

  group('BuildReport', () {
    test('sales report totals', () async {
      f.reports.sales = figures(
        count: 2,
        net: 1500,
        tax: 270,
        returnsNet: 200,
        returnsCount: 1,
      );
      final doc = (await f.build(ReportKind.sales, f.filter)).getOrThrow();
      expect(metric(doc, 'Net sales').money, inr(1300));
      expect(doc.scope, isEmpty);
    });
    test('purchase report uses purchase figures', () async {
      f.reports.purchases = figures(count: 1, net: 400);
      f.reports.sales = figures(count: 9, net: 9999);
      final doc = (await f.build(ReportKind.purchases, f.filter)).getOrThrow();
      expect(metric(doc, 'Net purchases').money, inr(400));
    });
    test('scope names the customer filter', () async {
      final now = f.pay.clock.now();
      f.pay.customers.items['c1'] = Customer(
        id: 'c1',
        name: 'Acme Traders',
        openingBalance: inr(0),
        createdAt: now,
        updatedAt: now,
      );
      final doc = (await f.build(
        ReportKind.sales,
        ReportFilter(range: f.range, customerId: 'c1'),
      )).getOrThrow();
      expect(doc.scope, ['Customer: Acme Traders']);
      expect(f.reports.filters.last.customerId, 'c1');
    });
    test('a filter the report does not support is not listed', () async {
      final doc = (await f.build(
        ReportKind.sales,
        ReportFilter(range: f.range, supplierId: 's1'),
      )).getOrThrow();
      expect(doc.scope, isEmpty);
    });
    test('profitability uses the shared profit calculation', () async {
      f.reports.sales = figures(count: 1, net: 2000);
      f.reports.cogs = inr(1200);
      f.expenses.stub = _expenseReport(
        ExpenseReportFilter(from: f.range.from, to: f.range.to),
        300,
        0,
      );
      final doc = (await f.build(
        ReportKind.profitability,
        f.filter,
      )).getOrThrow();
      expect(metric(doc, 'Gross profit').money, inr(800));
      expect(metric(doc, 'Operating result').money, inr(500));
    });
    test('payments, expenses and product reports build', () async {
      for (final k in [
        ReportKind.payments,
        ReportKind.expenses,
        ReportKind.productPerformance,
        ReportKind.stockMovements,
      ]) {
        expect((await f.build(k, f.filter)).isSuccess, isTrue);
      }
    });
    test('inventory, low-stock and outstanding reports build', () async {
      for (final k in [
        ReportKind.inventory,
        ReportKind.lowStock,
        ReportKind.customerOutstanding,
        ReportKind.supplierOutstanding,
      ]) {
        final r = await f.build(k, f.filter);
        expect(r.isSuccess, isTrue);
        expect(r.valueOrNull!.periodText, isNull);
      }
    });
    test('outstanding report lists only parties with a balance', () async {
      final now = f.pay.clock.now();
      f.pay.customers.items['c1'] = Customer(
        id: 'c1',
        name: 'Acme Traders',
        openingBalance: inr(5000),
        createdAt: now,
        updatedAt: now,
      );
      final doc = (await f.build(
        ReportKind.customerOutstanding,
        f.filter,
      )).getOrThrow();
      expect(doc.tables.single.rows, hasLength(1));
      expect(metric(doc, 'Total receivable').money, inr(5000));
    });
    test('a database failure becomes a failure result', () async {
      f.reports.failure = const DatabaseFailure('boom');
      final r = await f.build(ReportKind.sales, f.filter);
      expect(r.failureOrNull, isA<DatabaseFailure>());
    });
    test('every kind builds a document named after it', () async {
      for (final k in ReportKind.values) {
        final doc = (await f.build(k, f.filter)).getOrThrow();
        expect(doc.kind, k.name);
        expect(doc.title, k.title);
      }
    });
  });

  group('GetDashboard', () {
    test('assembles every figure', () async {
      f.reports.sales = figures(count: 2, net: 1500, returnsNet: 200);
      f.reports.purchases = figures(count: 1, net: 400);
      f.reports.cogs = inr(700);
      f.reports.salesRowList = [
        DocumentRow(
          id: 'a',
          number: 'INV-1',
          date: DateTime.utc(2026, 11, 3),
          partyName: 'X',
          net: inr(1),
          tax: inr(0),
          total: inr(1),
        ),
      ];
      final now = f.pay.clock.now();
      f.pay.customers.items['c1'] = Customer(
        id: 'c1',
        name: 'Acme',
        openingBalance: inr(900),
        createdAt: now,
        updatedAt: now,
      );
      f.expenses.stub = _expenseReport(
        ExpenseReportFilter(from: f.range.from, to: f.range.to),
        100,
        0,
      );
      final s = (await f.dashboard(f.range)).getOrThrow();
      expect(s.sales.netAfterReturns, inr(1300));
      expect(s.profit.grossProfit, inr(600));
      expect(s.profit.operatingResult, inr(500));
      expect(s.receivable, inr(900));
      expect(s.payable, inr(0));
      expect(s.recentSales, hasLength(1));
      expect(s.chart.series.map((x) => x.name).toList(), [
        'Sales',
        'Purchases',
      ]);
      expect(s.chart.labels, hasLength(15));
      expect(s.isBlank, isFalse);
    });
    test('top products, trend and derived figures', () async {
      f.reports.sales = figures(
        count: 3,
        net: 3000,
        tax: 540,
        returnsNet: 0,
        returnsTax: 36,
      );
      f.reports.salesSeries = DailySeries(
        documents: [
          DatedAmount(DateTime.utc(2026, 11, 2), inr(1000)),
          DatedAmount(DateTime.utc(2026, 11, 4), inr(2000)),
        ],
        returns: [DatedAmount(DateTime.utc(2026, 11, 4), inr(500))],
      );
      ProductFigures product(String id, int revenue) => ProductFigures(
        productId: id,
        name: id,
        sku: id,
        unitSymbol: 'pcs',
        unitDecimalPlaces: 0,
        quantitySold: const Quantity.fromMilli(1000),
        quantityReturned: Quantity.zero,
        revenue: inr(revenue),
        returnedRevenue: inr(0),
        cost: inr(0),
      );
      f.reports.products = [
        for (var i = 0; i < 7; i++) product('p$i', 700 - i * 100),
        product('loss', -5),
      ];
      final s = (await f.dashboard(f.range)).getOrThrow();
      expect(s.topProducts.map((p) => p.productId).toList(), [
        'p0',
        'p1',
        'p2',
        'p3',
        'p4',
      ]);
      expect(s.averageSale, inr(1000));
      expect(s.taxCollected, inr(504));
      final trend = s.trendChart.series.single.values;
      expect(trend, hasLength(15));
      expect(trend.last, 2500);
      expect(trend[1], 1000);
      expect(trend[2], 1000);
      expect(trend[3], 2500); // day 4: +2000 sales - 500 returns
    });
    test('healthy stock never goes negative; average needs invoices', () async {
      final s = (await f.dashboard(f.range)).getOrThrow();
      expect(s.healthyStockCount, 0);
      expect(s.averageSale, isNull);
    });
    test('a fresh database is blank', () async {
      final s = (await f.dashboard(f.range)).getOrThrow();
      expect(s.isBlank, isTrue);
      expect(s.inventory.lowStockCount, 0);
    });
    test('only positive balances are receivable', () async {
      final now = f.pay.clock.now();
      f.pay.customers.items['c1'] = Customer(
        id: 'c1',
        name: 'Acme',
        openingBalance: inr(-300),
        createdAt: now,
        updatedAt: now,
      );
      f.pay.customers.items['c2'] = Customer(
        id: 'c2',
        name: 'Beta',
        openingBalance: inr(1000),
        createdAt: now,
        updatedAt: now,
      );
      final s = (await f.dashboard(f.range)).getOrThrow();
      expect(s.receivable, inr(1000));
    });
    test('a failure anywhere fails the dashboard', () async {
      f.reports.failure = const DatabaseFailure('boom');
      expect((await f.dashboard(f.range)).isFailure, isTrue);
    });
  });

  group('ExportReportCsv', () {
    test('shares the CSV of the document under a dated name', () async {
      f.reports.sales = figures(count: 1, net: 100);
      final doc = (await f.build(ReportKind.sales, f.filter)).getOrThrow();
      final r = await f.export(doc);
      expect(r.isSuccess, isTrue);
      expect(f.exporter.fileName, 'inventrix-sales-2026-03-10.csv');
      expect(f.exporter.content, contains('Sales report'));
    });
    test('slug is used for multi-word kinds', () async {
      final doc = (await f.build(
        ReportKind.productPerformance,
        f.filter,
      )).getOrThrow();
      expect(ExportReportCsv.fileNameFor(doc), contains('product-performance'));
    });
    test('export failure is returned', () async {
      f.exporter.failure = const UnexpectedFailure('no');
      final doc = (await f.build(ReportKind.sales, f.filter)).getOrThrow();
      expect((await f.export(doc)).isFailure, isTrue);
    });
  });
}
