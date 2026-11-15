import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/reports/data/repositories/report_queries.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/repositories/report_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Drift implementation of [ReportRepository]: plain SQL aggregates over the
/// local database (see `report_queries.dart`). Nothing is written.
final class DriftReportRepository implements ReportRepository {
  /// Creates the repository.
  const DriftReportRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  static const int _msPerDay = 86400000;

  @override
  Future<Result<DocumentFigures>> salesFigures(ReportFilter filter) => _figures(
    filter,
    filter.customerId,
    salesFiguresSql,
    salesReturnFiguresSql,
    salesOtherCurrencySql,
  );

  @override
  Future<Result<DocumentFigures>> purchaseFigures(ReportFilter filter) =>
      _figures(
        filter,
        filter.supplierId,
        purchaseFiguresSql,
        purchaseReturnFiguresSql,
        purchaseOtherCurrencySql,
      );

  @override
  Future<Result<List<DocumentRow>>> salesRows(
    ReportFilter filter, {
    required int limit,
  }) => _rows(salesRowsSql, filter, filter.customerId, limit);

  @override
  Future<Result<List<DocumentRow>>> purchaseRows(
    ReportFilter filter, {
    required int limit,
  }) => _rows(purchaseRowsSql, filter, filter.supplierId, limit);

  @override
  Future<Result<DailySeries>> salesByDay(ReportFilter filter) =>
      _daily(filter, filter.customerId, salesDailySql, salesReturnsDailySql);

  @override
  Future<Result<DailySeries>> purchasesByDay(ReportFilter filter) => _daily(
    filter,
    filter.supplierId,
    purchaseDailySql,
    purchaseReturnsDailySql,
  );

  @override
  Future<Result<List<DocumentRow>>> recentSales(int limit) =>
      _recent(recentSalesSql, limit);

  @override
  Future<Result<List<DocumentRow>>> recentPurchases(int limit) =>
      _recent(recentPurchaseSql, limit);

  @override
  Future<Result<Money>> costOfGoodsSold(DateRange range) =>
      guardDatabase(() async {
        final c = await _currency();
        final args = _rangeArgs(range, c);
        final row = await _db
            .customSelect(costOfGoodsSoldSql, variables: [...args, ...args])
            .getSingle();
        final sold = row.read<int>('sold_cost');
        final returned = row.read<int>('returned_cost');
        return c.fromMinor(sold - returned);
      });

  @override
  Future<Result<List<ProductFigures>>> productFigures(
    ReportFilter filter,
  ) => guardDatabase(() async {
    final c = await _currency();
    final args = [
      ..._rangeArgs(filter.range, c),
      Variable<String>(filter.productId),
      Variable<String>(filter.productId),
    ];
    final sold = await _db.customSelect(productSoldSql, variables: args).get();
    final returned = await _db
        .customSelect(productReturnedSql, variables: args)
        .get();
    final cost = await _db.customSelect(productCostSql, variables: args).get();

    final byProduct = <String, _ProductAcc>{};
    _ProductAcc acc(QueryRow row) => byProduct.putIfAbsent(
      row.read<String>('product_id'),
      () => _ProductAcc(
        name: row.read<String>('name'),
        sku: row.read<String>('sku'),
        unitSymbol: row.read<String>('unit_symbol'),
        unitDecimals: row.read<int>('unit_dp'),
      ),
    );
    for (final row in sold) {
      acc(row)
        ..soldMilli = row.read<int>('qty')
        ..revenue = row.read<int>('revenue');
    }
    for (final row in returned) {
      acc(row)
        ..returnedMilli = row.read<int>('qty')
        ..returnedRevenue = row.read<int>('revenue')
        ..restockedCost = row.read<int>('restocked_cost');
    }
    for (final row in cost) {
      final a = byProduct[row.read<String>('product_id')];
      if (a != null) {
        a.soldCost = row.read<int>('cost');
      }
    }
    final list =
        [
          for (final entry in byProduct.entries)
            ProductFigures(
              productId: entry.key,
              name: entry.value.name,
              sku: entry.value.sku,
              unitSymbol: entry.value.unitSymbol,
              unitDecimalPlaces: entry.value.unitDecimals,
              quantitySold: Quantity.fromMilli(entry.value.soldMilli),
              quantityReturned: Quantity.fromMilli(entry.value.returnedMilli),
              revenue: c.fromMinor(entry.value.revenue),
              returnedRevenue: c.fromMinor(entry.value.returnedRevenue),
              cost: c.fromMinor(
                entry.value.soldCost - entry.value.restockedCost,
              ),
            ),
        ]..sort((a, b) {
          final byRevenue = b.netRevenue.compareTo(a.netRevenue);
          return byRevenue != 0 ? byRevenue : a.name.compareTo(b.name);
        });
    return list;
  });

  @override
  Future<Result<CashFigures>> cashFigures(ReportFilter filter) => guardDatabase(
    () async {
      final c = await _currency();
      final customer = filter.customerId;
      final supplier = filter.supplierId;
      // A customer filter leaves out the supplier side and vice versa;
      // with both set, both sides are shown for their party.
      final includeCustomerSide = customer != null || supplier == null;
      final includeSupplierSide = supplier != null || customer == null;
      final base = _rangeArgs(filter.range, c);
      final customerArgs = <Variable<Object>>[
        Variable.withInt(includeCustomerSide ? 1 : 0),
        Variable<String>(customer),
        Variable<String>(customer),
      ];
      final supplierArgs = <Variable<Object>>[
        Variable.withInt(includeSupplierSide ? 1 : 0),
        Variable<String>(supplier),
        Variable<String>(supplier),
      ];
      final variables = <Variable<Object>>[
        ...base,
        ...customerArgs,
        ...supplierArgs,
        ...base,
        ...customerArgs,
        ...base,
        ...supplierArgs,
      ];
      final rows = await _db.customSelect(cashSql, variables: variables).get();
      final other = await _db
          .customSelect(cashOtherCurrencySql, variables: variables)
          .getSingle();

      var customerPayments = 0;
      var customerRefunds = 0;
      var supplierPayments = 0;
      var supplierRefunds = 0;
      var salesReturnRefunds = 0;
      var purchaseReturnRefunds = 0;
      var entries = 0;
      final methods = <String, _MethodAcc>{};
      for (final row in rows) {
        final cat = row.read<String>('cat');
        final amount = row.read<int>('amount');
        entries += row.read<int>('cnt');
        final isIn = switch (cat) {
          'customer/payment' => true,
          'supplier/refund' => true,
          'purchaseReturnRefund' => true,
          _ => false,
        };
        switch (cat) {
          case 'customer/payment':
            customerPayments += amount;
          case 'customer/refund':
            customerRefunds += amount;
          case 'supplier/payment':
            supplierPayments += amount;
          case 'supplier/refund':
            supplierRefunds += amount;
          case 'salesReturnRefund':
            salesReturnRefunds += amount;
          case 'purchaseReturnRefund':
            purchaseReturnRefunds += amount;
        }
        final method = methods.putIfAbsent(
          row.read<String>('method_id'),
          () => _MethodAcc(row.read<String>('method_name')),
        );
        if (isIn) {
          method.moneyIn += amount;
        } else {
          method.moneyOut += amount;
        }
      }
      final byMethod =
          [
            for (final e in methods.entries)
              MethodCash(
                methodId: e.key,
                methodName: e.value.name,
                moneyIn: c.fromMinor(e.value.moneyIn),
                moneyOut: c.fromMinor(e.value.moneyOut),
              ),
          ]..sort((a, b) {
            final turnoverA = a.moneyIn.minorUnits + a.moneyOut.minorUnits;
            final turnoverB = b.moneyIn.minorUnits + b.moneyOut.minorUnits;
            return turnoverB != turnoverA
                ? turnoverB.compareTo(turnoverA)
                : a.methodName.compareTo(b.methodName);
          });
      return CashFigures(
        customerPayments: c.fromMinor(customerPayments),
        customerRefunds: c.fromMinor(customerRefunds),
        supplierPayments: c.fromMinor(supplierPayments),
        supplierRefunds: c.fromMinor(supplierRefunds),
        salesReturnRefunds: c.fromMinor(salesReturnRefunds),
        purchaseReturnRefunds: c.fromMinor(purchaseReturnRefunds),
        entryCount: entries,
        byMethod: byMethod,
        otherCurrencyCount: other.read<int>('cnt'),
      );
    },
  );

  @override
  Future<Result<MovementReportData>> stockMovements(
    ReportFilter filter, {
    required int limit,
  }) => guardDatabase(() async {
    final c = await _currency();
    final from = toEpochMs(filter.range.from);
    // `occurred_at` is a timestamp: include the whole last day (UTC).
    final to = toEpochMs(filter.range.to) + _msPerDay;
    final range = <Variable<Object>>[
      Variable.withInt(from),
      Variable.withInt(to),
      Variable<String>(filter.productId),
      Variable<String>(filter.productId),
    ];
    final rows = await _db
        .customSelect(
          movementRowsSql,
          variables: [...range, Variable.withInt(limit)],
        )
        .get();
    final totals = await _db
        .customSelect(movementTotalsSql, variables: range)
        .getSingle();
    return MovementReportData(
      rows: [
        for (final row in rows)
          MovementRow(
            id: row.read<String>('id'),
            occurredAt: fromEpochMs(row.read<int>('occurred_at')),
            productName: row.read<String>('product_name'),
            sku: row.read<String>('sku'),
            type: StockMovementType.fromDbName(
              row.read<String>('movement_type'),
            ),
            quantity: Quantity.fromMilli(row.read<int>('qty')),
            unitDecimalPlaces: row.read<int>('unit_dp'),
            unitSymbol: row.read<String>('unit_symbol'),
            value: c.fromMinor(row.read<int>('cost')),
            reason: row.readNullable<String>('reason'),
          ),
      ],
      totalCount: totals.read<int>('cnt'),
      valueIn: c.fromMinor(totals.read<int>('value_in')),
      valueOut: c.fromMinor(totals.read<int>('value_out')),
    );
  });

  // ---------------------------------------------------------------- helpers

  Future<CurrencyConfig> _currency() async {
    final result = await _settings.getCurrencyConfig();
    final currency = result.valueOrNull;
    if (currency == null) {
      throw FailureException(result.failureOrNull!);
    }
    return currency;
  }

  List<Variable<Object>> _rangeArgs(DateRange range, CurrencyConfig c) => [
    Variable.withInt(toEpochMs(range.from)),
    Variable.withInt(toEpochMs(range.to)),
    Variable.withString(c.currencyCode),
    Variable.withInt(c.decimalPlaces),
  ];

  List<Variable<Object>> _docArgs(
    ReportFilter filter,
    CurrencyConfig c,
    String? party,
  ) => [
    ..._rangeArgs(filter.range, c),
    Variable<String>(party),
    Variable<String>(party),
  ];

  Future<Result<DocumentFigures>> _figures(
    ReportFilter filter,
    String? party,
    String documentsSql,
    String returnsSql,
    String otherSql,
  ) => guardDatabase(() async {
    final c = await _currency();
    final args = _docArgs(filter, c, party);
    final docs = await _db
        .customSelect(documentsSql, variables: args)
        .getSingle();
    final rets = await _db
        .customSelect(returnsSql, variables: args)
        .getSingle();
    final other = await _db
        .customSelect(otherSql, variables: [...args, ...args])
        .getSingle();
    return DocumentFigures(
      count: docs.read<int>('cnt'),
      net: c.fromMinor(docs.read<int>('net')),
      tax: c.fromMinor(docs.read<int>('tax')),
      total: c.fromMinor(docs.read<int>('total')),
      returnsCount: rets.read<int>('cnt'),
      returnsNet: c.fromMinor(rets.read<int>('net')),
      returnsTax: c.fromMinor(rets.read<int>('tax')),
      returnsTotal: c.fromMinor(rets.read<int>('total')),
      otherCurrencyCount: other.read<int>('cnt'),
    );
  });

  Future<Result<List<DocumentRow>>> _rows(
    String sql,
    ReportFilter filter,
    String? party,
    int limit,
  ) => guardDatabase(() async {
    final c = await _currency();
    final rows = await _db
        .customSelect(
          sql,
          variables: [..._docArgs(filter, c, party), Variable.withInt(limit)],
        )
        .get();
    return [for (final row in rows) _documentRow(row, c)];
  });

  Future<Result<List<DocumentRow>>> _recent(String sql, int limit) =>
      guardDatabase(() async {
        final c = await _currency();
        final rows = await _db
            .customSelect(
              sql,
              variables: [
                Variable.withString(c.currencyCode),
                Variable.withInt(c.decimalPlaces),
                Variable.withInt(limit),
              ],
            )
            .get();
        return [for (final row in rows) _documentRow(row, c)];
      });

  Future<Result<DailySeries>> _daily(
    ReportFilter filter,
    String? party,
    String documentsSql,
    String returnsSql,
  ) => guardDatabase(() async {
    final c = await _currency();
    final args = _docArgs(filter, c, party);
    List<DatedAmount> read(List<QueryRow> rows) => [
      for (final row in rows)
        DatedAmount(
          fromEpochMs(row.read<int>('day')),
          c.fromMinor(row.read<int>('amount')),
        ),
    ];
    final docs = await _db.customSelect(documentsSql, variables: args).get();
    final rets = await _db.customSelect(returnsSql, variables: args).get();
    return DailySeries(documents: read(docs), returns: read(rets));
  });

  DocumentRow _documentRow(QueryRow row, CurrencyConfig c) => DocumentRow(
    id: row.read<String>('id'),
    number: row.read<String>('number'),
    date: fromEpochMs(row.read<int>('invoice_date')),
    partyName: row.read<String>('party_name'),
    net: c.fromMinor(row.read<int>('net_total_minor')),
    tax: c.fromMinor(row.read<int>('tax_total_minor')),
    total: c.fromMinor(row.read<int>('total_minor')),
  );
}

class _ProductAcc {
  _ProductAcc({
    required this.name,
    required this.sku,
    required this.unitSymbol,
    required this.unitDecimals,
  });

  final String name;
  final String sku;
  final String unitSymbol;
  final int unitDecimals;
  int soldMilli = 0;
  int returnedMilli = 0;
  int revenue = 0;
  int returnedRevenue = 0;
  int soldCost = 0;
  int restockedCost = 0;
}

class _MethodAcc {
  _MethodAcc(this.name);

  final String name;
  int moneyIn = 0;
  int moneyOut = 0;
}
