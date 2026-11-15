import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/products.dart';

/// Append-only stock ledger. Rows can never be updated or deleted
/// (enforced by triggers created in the initial migration).
@DataClassName('StockMovementRow')
@TableIndex(
  name: 'idx_stock_movements_product_occurred',
  columns: {#productId, #occurredAt},
)
class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  TextColumn get movementType => text().customConstraint(
    'NOT NULL CHECK (movement_type IN ('
    "'openingStock','purchase','sale','salesReturn','purchaseReturn',"
    "'adjustmentIn','adjustmentOut','reversal'))",
  )();

  /// Signed change in milli-units (positive = stock in).
  IntColumn get quantityDeltaMilli => integer().customConstraint(
    'NOT NULL CHECK (quantity_delta_milli <> 0)',
  )();

  /// Signed value change in minor units, same sign as the quantity delta.
  IntColumn get totalCostMinor => integer()();
  IntColumn get unitCostMinorSnapshot => integer()();
  TextColumn get sourceType => text().nullable()();
  TextColumn get sourceId => text().nullable()();
  TextColumn get sourceLineId => text().nullable()();
  TextColumn get reason => text().nullable()();
  IntColumn get occurredAt => integer()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (movement_type NOT IN ('openingStock','purchase','salesReturn',"
        "'adjustmentIn') OR quantity_delta_milli > 0)",
    "CHECK (movement_type NOT IN ('sale','purchaseReturn',"
        "'adjustmentOut') OR quantity_delta_milli < 0)",
    'CHECK (total_cost_minor = 0 OR '
        '(total_cost_minor > 0) = (quantity_delta_milli > 0))',
    "CHECK (movement_type NOT IN ('adjustmentIn','adjustmentOut') OR "
        '(reason IS NOT NULL AND length(trim(reason)) > 0))',
    'CHECK ((source_type IS NULL) = (source_id IS NULL))',
    'CHECK (source_id IS NULL OR source_line_id IS NOT NULL)',
  ];
}
