import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Balance row -> entity (values interpreted in [currency]).
StockBalance balanceFromRow(InventoryBalanceRow row, CurrencyConfig currency) =>
    StockBalance(
      productId: row.productId,
      quantityOnHand: Quantity.fromMilli(row.quantityOnHandMilli),
      inventoryValue: currency.fromMinor(row.inventoryValueMinor),
      updatedAt: fromEpochMs(row.updatedAt),
    );

/// An empty balance for a product that has no balance row yet.
StockBalance emptyBalance(String productId, CurrencyConfig currency) =>
    StockBalance(
      productId: productId,
      quantityOnHand: Quantity.zero,
      inventoryValue: currency.zero(),
    );

/// Movement row -> entity.
StockMovement movementFromRow(StockMovementRow row, CurrencyConfig currency) =>
    StockMovement(
      id: row.id,
      productId: row.productId,
      type: StockMovementType.fromDbName(row.movementType),
      quantityDelta: Quantity.fromMilli(row.quantityDeltaMilli),
      totalCost: currency.fromMinor(row.totalCostMinor),
      unitCost: currency.fromMinor(row.unitCostMinorSnapshot),
      sourceType: row.sourceType,
      sourceId: row.sourceId,
      sourceLineId: row.sourceLineId,
      reason: row.reason,
      occurredAt: fromEpochMs(row.occurredAt),
      createdAt: fromEpochMs(row.createdAt),
    );

/// Movement entity -> insert companion.
StockMovementsCompanion movementToCompanion(StockMovement movement) =>
    StockMovementsCompanion(
      id: Value(movement.id),
      productId: Value(movement.productId),
      movementType: Value(movement.type.dbName),
      quantityDeltaMilli: Value(movement.quantityDelta.milli),
      totalCostMinor: Value(movement.totalCost.minorUnits),
      unitCostMinorSnapshot: Value(movement.unitCost.minorUnits),
      sourceType: Value(movement.sourceType),
      sourceId: Value(movement.sourceId),
      sourceLineId: Value(movement.sourceLineId),
      reason: Value(movement.reason),
      occurredAt: Value(toEpochMs(movement.occurredAt)),
      createdAt: Value(toEpochMs(movement.createdAt)),
    );
