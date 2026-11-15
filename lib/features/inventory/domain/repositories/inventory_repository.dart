import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/inventory/domain/entities/inventory_valuation.dart';
import 'package:inventrix/features/inventory/domain/entities/reconciliation.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_item.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_position.dart';

/// Persistence contract for the stock ledger and its balance projection.
abstract interface class InventoryRepository {
  /// Lists products with their balances, ordered by product name.
  Future<Result<List<StockItem>>> listStock(StockFilter filter);

  /// One product with its balance; `NotFoundFailure` for unknown products.
  Future<Result<StockItem>> getStockItem(String productId);

  /// The balance of [productId]; an empty balance if none exists yet.
  Future<Result<StockBalance>> getBalance(String productId);

  /// Every stored balance row.
  Future<Result<List<StockBalance>>> allBalances();

  /// Ledger entries for [productId], newest first.
  Future<Result<List<StockMovement>>> movements(
    String productId, {
    int limit = 50,
    int offset = 0,
  });

  /// Ledger entries created by one source document (for example the stock
  /// movements of a posted sales invoice), oldest first.
  Future<Result<List<StockMovement>>> movementsForSource(
    String sourceType,
    String sourceId,
  );

  /// Whether [productId] has any ledger entry.
  Future<Result<bool>> hasMovements(String productId);

  /// Per-product sums over the whole ledger.
  Future<Result<List<LedgerTotals>>> ledgerTotals();

  /// Inventory totals and low/out counts.
  Future<Result<InventoryValuation>> valuation();

  /// Appends [movement] and sets the balance to [newPosition].
  ///
  /// Must be called inside `TransactionRunner.runResult` so both writes
  /// commit or roll back together.
  Future<Result<void>> applyMovement(
    StockMovement movement,
    StockPosition newPosition,
  );

  /// Overwrites the balance of [productId] (reconciliation repair only).
  Future<Result<void>> replaceBalance(
    String productId,
    StockPosition position,
    DateTime at,
  );
}
