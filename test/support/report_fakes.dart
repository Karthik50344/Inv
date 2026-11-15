import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_exporter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_repository.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

DocumentFigures figures({
  int count = 0,
  int net = 0,
  int tax = 0,
  int returnsCount = 0,
  int returnsNet = 0,
  int returnsTax = 0,
  int other = 0,
}) => DocumentFigures(
  count: count,
  net: inr(net),
  tax: inr(tax),
  total: inr(net + tax),
  returnsCount: returnsCount,
  returnsNet: inr(returnsNet),
  returnsTax: inr(returnsTax),
  returnsTotal: inr(returnsNet + returnsTax),
  otherCurrencyCount: other,
);

/// Report repository returning configured values; records the filters it saw.
class FakeReportRepository implements ReportRepository {
  DocumentFigures sales = figures();
  DocumentFigures purchases = figures();
  List<DocumentRow> salesRowList = [];
  List<DocumentRow> purchaseRowList = [];
  DailySeries salesSeries = const DailySeries(documents: [], returns: []);
  DailySeries purchaseSeries = const DailySeries(documents: [], returns: []);
  Money cogs = inr(0);
  List<ProductFigures> products = [];
  CashFigures cash = CashFigures.empty(inr(0));
  MovementReportData movements = MovementReportData(
    rows: const [],
    totalCount: 0,
    valueIn: inr(0),
    valueOut: inr(0),
  );
  Failure? failure;
  final List<ReportFilter> filters = [];

  Result<T> _r<T>(T value, [ReportFilter? f]) {
    if (f != null) {
      filters.add(f);
    }
    return failure != null ? Result.failure(failure!) : Result.success(value);
  }

  @override
  Future<Result<DocumentFigures>> salesFigures(ReportFilter f) async =>
      _r(sales, f);
  @override
  Future<Result<DocumentFigures>> purchaseFigures(ReportFilter f) async =>
      _r(purchases, f);
  @override
  Future<Result<List<DocumentRow>>> salesRows(
    ReportFilter f, {
    required int limit,
  }) async => _r(salesRowList.take(limit).toList(), f);
  @override
  Future<Result<List<DocumentRow>>> purchaseRows(
    ReportFilter f, {
    required int limit,
  }) async => _r(purchaseRowList.take(limit).toList(), f);
  @override
  Future<Result<DailySeries>> salesByDay(ReportFilter f) async =>
      _r(salesSeries);
  @override
  Future<Result<DailySeries>> purchasesByDay(ReportFilter f) async =>
      _r(purchaseSeries);
  @override
  Future<Result<Money>> costOfGoodsSold(DateRange range) async => _r(cogs);
  @override
  Future<Result<List<ProductFigures>>> productFigures(ReportFilter f) async =>
      _r(products, f);
  @override
  Future<Result<CashFigures>> cashFigures(ReportFilter f) async => _r(cash, f);
  @override
  Future<Result<MovementReportData>> stockMovements(
    ReportFilter f, {
    required int limit,
  }) async => _r(movements, f);
  @override
  Future<Result<List<DocumentRow>>> recentSales(int limit) async =>
      _r(salesRowList.take(limit).toList());
  @override
  Future<Result<List<DocumentRow>>> recentPurchases(int limit) async =>
      _r(purchaseRowList.take(limit).toList());
}

class FakeReportExporter implements ReportExporter {
  String? fileName;
  String? content;
  Failure? failure;

  @override
  Future<Result<void>> shareCsv({
    required String fileName,
    required String content,
    required String subject,
  }) async {
    this.fileName = fileName;
    this.content = content;
    return failure != null
        ? Result.failure(failure!)
        : const Result.success(null);
  }
}
