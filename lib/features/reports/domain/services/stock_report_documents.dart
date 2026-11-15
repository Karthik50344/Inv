import 'package:inventrix/features/inventory/domain/entities/stock_item.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/services/report_text.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Builds the inventory, low-stock and stock movement reports.
abstract final class StockReportDocuments {
  static String _statusLabel(StockStatus status) => switch (status) {
    StockStatus.ok => 'In stock',
    StockStatus.low => 'Low',
    StockStatus.out => 'Out of stock',
  };

  /// Stock on hand with its value. [items] should include archived
  /// products so the total equals the inventory value of the ledger.
  static ReportDocument inventory({
    required DateTime generatedAt,
    required List<StockItem> items,
    required Map<String, UnitOfMeasure> units,
    required Money zero,
  }) {
    var total = zero;
    var inStock = 0;
    var low = 0;
    var out = 0;
    final rows = <List<ReportCell>>[];
    for (final item in items) {
      final unit = units[item.product.unitId];
      final decimals = unit?.decimalPlaces ?? 3;
      total += item.balance.inventoryValue;
      final status = item.status;
      if (item.balance.quantityOnHand.isPositive) {
        inStock++;
      }
      if (!item.product.isArchived) {
        if (status == StockStatus.low) {
          low++;
        } else if (status == StockStatus.out) {
          out++;
        }
      }
      final average = item.balance.averageCost;
      rows.add([
        TextCell(item.product.sku),
        TextCell(
          item.product.isArchived
              ? '${item.product.name} (archived)'
              : item.product.name,
        ),
        QuantityCell(
          item.balance.quantityOnHand,
          decimals: decimals,
          unit: unit?.symbol ?? '',
        ),
        average == null ? const EmptyCell() : MoneyCell(average),
        MoneyCell(item.balance.inventoryValue),
        TextCell(_statusLabel(status)),
      ]);
    }
    return ReportDocument(
      kind: ReportKind.inventory.name,
      title: ReportKind.inventory.title,
      generatedAt: generatedAt,
      metrics: [
        ReportMetric('Inventory value', MoneyCell(total)),
        ReportMetric('Products with stock', CountCell(inStock)),
        ReportMetric('Low stock', CountCell(low)),
        ReportMetric('Out of stock', CountCell(out)),
      ],
      tables: [
        ReportTable(
          title: 'Stock on hand',
          columns: const [
            ReportColumn('SKU'),
            ReportColumn('Product'),
            ReportColumn('On hand', numeric: true),
            ReportColumn('Average cost', numeric: true),
            ReportColumn('Value', numeric: true),
            ReportColumn('Status'),
          ],
          rows: rows,
        ),
      ],
      notes: const [
        'Value is the stock ledger valued at weighted average cost.',
        'Archived products that still hold stock are included.',
        'Low and out-of-stock counts cover active products only.',
      ],
    );
  }

  /// Products at or below their reorder level or without stock. [items]
  /// must already be filtered to low and out-of-stock products.
  static ReportDocument lowStock({
    required DateTime generatedAt,
    required List<StockItem> items,
    required Map<String, UnitOfMeasure> units,
  }) {
    final lowCount = items.where((i) => i.status == StockStatus.low).length;
    final outCount = items.where((i) => i.status == StockStatus.out).length;
    return ReportDocument(
      kind: ReportKind.lowStock.name,
      title: ReportKind.lowStock.title,
      generatedAt: generatedAt,
      metrics: [
        ReportMetric('Low stock', CountCell(lowCount)),
        ReportMetric('Out of stock', CountCell(outCount)),
      ],
      tables: [
        ReportTable(
          title: 'Products to reorder',
          columns: const [
            ReportColumn('SKU'),
            ReportColumn('Product'),
            ReportColumn('On hand', numeric: true),
            ReportColumn('Reorder level', numeric: true),
            ReportColumn('Status'),
          ],
          rows: [
            for (final item in items)
              [
                TextCell(item.product.sku),
                TextCell(item.product.name),
                QuantityCell(
                  item.balance.quantityOnHand,
                  decimals: units[item.product.unitId]?.decimalPlaces ?? 3,
                  unit: units[item.product.unitId]?.symbol ?? '',
                ),
                QuantityCell(
                  item.product.reorderLevel,
                  decimals: units[item.product.unitId]?.decimalPlaces ?? 3,
                  unit: units[item.product.unitId]?.symbol ?? '',
                ),
                TextCell(_statusLabel(item.status)),
              ],
          ],
        ),
      ],
      notes: const [
        'Active products only. A product is low when its stock is at or '
            'below its reorder level, and out when nothing is left.',
        'Products without a reorder level are only listed when out of '
            'stock.',
      ],
    );
  }

  /// The stock ledger of a period.
  static ReportDocument movements({
    required ReportFilter filter,
    required DateTime generatedAt,
    required List<String> scope,
    required MovementReportData data,
  }) {
    return ReportDocument(
      kind: ReportKind.stockMovements.name,
      title: ReportKind.stockMovements.title,
      generatedAt: generatedAt,
      periodText: ReportText.period(filter.range),
      scope: scope,
      metrics: [
        ReportMetric('Entries', CountCell(data.totalCount)),
        ReportMetric('Value in', MoneyCell(data.valueIn)),
        ReportMetric('Value out', MoneyCell(data.valueOut)),
        ReportMetric(
          'Net change in value',
          MoneyCell(data.valueIn - data.valueOut),
        ),
      ],
      tables: [
        ReportTable(
          title: 'Stock ledger',
          columns: const [
            ReportColumn('Date'),
            ReportColumn('Product'),
            ReportColumn('SKU'),
            ReportColumn('Type'),
            ReportColumn('Quantity', numeric: true),
            ReportColumn('Value', numeric: true),
            ReportColumn('Reason'),
          ],
          rows: [
            for (final r in data.rows)
              [
                DateCell(r.occurredAt),
                TextCell(r.productName),
                TextCell(r.sku),
                TextCell(r.type.label),
                QuantityCell(
                  r.quantity,
                  decimals: r.unitDecimalPlaces,
                  unit: r.unitSymbol,
                ),
                MoneyCell(r.value),
                r.reason == null ? const EmptyCell() : TextCell(r.reason!),
              ],
          ],
          totalRowCount: data.totalCount,
        ),
      ],
      notes: const [
        'The ledger is the source of truth for stock: every increase and '
            'decrease appears here, including reversals.',
        'Value in and out are the cost of the stock that moved.',
      ],
    );
  }
}
