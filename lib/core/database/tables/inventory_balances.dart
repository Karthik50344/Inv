import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/products.dart';

/// Maintained projection of the stock ledger (one row per product).
///
/// `stock_movements` is the source of truth; this table is updated in the
/// same transaction as every movement and can be reconciled against it.
@DataClassName('InventoryBalanceRow')
class InventoryBalances extends Table {
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  IntColumn get quantityOnHandMilli => integer().customConstraint(
    'NOT NULL CHECK (quantity_on_hand_milli >= 0)',
  )();
  IntColumn get inventoryValueMinor => integer().customConstraint(
    'NOT NULL CHECK (inventory_value_minor >= 0)',
  )();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {productId};

  @override
  List<String> get customConstraints => [
    // Zero stock must carry zero value (weighted-average invariant).
    'CHECK (quantity_on_hand_milli > 0 OR inventory_value_minor = 0)',
  ];
}
