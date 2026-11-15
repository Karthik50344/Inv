import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/inventory/domain/entities/inventory_valuation.dart';
import 'package:inventrix/features/inventory/domain/entities/reconciliation.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_item.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_position.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/products/domain/entities/product_filter.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import 'fakes.dart';

/// A fake whose state can be captured and restored to emulate rollback.
abstract interface class Rollbackable {
  Object snapshot();
  void restore(Object snapshot);
}

/// Transaction runner that restores its participants when the action fails.
class FakeTransactionRunner implements TransactionRunner {
  FakeTransactionRunner(this.participants);

  final List<Rollbackable> participants;
  int committed = 0;
  int rolledBack = 0;

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    final snapshots = [for (final p in participants) p.snapshot()];
    try {
      final value = await action();
      committed++;
      return value;
    } catch (_) {
      for (var i = 0; i < participants.length; i++) {
        participants[i].restore(snapshots[i]);
      }
      rolledBack++;
      rethrow;
    }
  }

  @override
  Future<Result<T>> runResult<T>(Future<T> Function() action) async {
    try {
      return Result.success(await run(action));
    } on FailureException catch (e) {
      return Result.failure(e.failure);
    } on Object catch (e, st) {
      return Result.failure(
        UnexpectedFailure('boom', cause: e, stackTrace: st),
      );
    }
  }
}

class FakeAuditLogRepository implements AuditLogRepository, Rollbackable {
  List<AuditEntry> entries = [];
  Failure? recordFailure;

  @override
  Future<Result<void>> record(AuditEntry entry) async {
    if (recordFailure != null) {
      return Result.failure(recordFailure!);
    }
    entries.add(entry);
    return const Result.success(null);
  }

  @override
  Future<Result<List<AuditEntry>>> forEntity(
    String entityType,
    String entityId, {
    int limit = 50,
  }) async => Result.success(
    entries
        .where((e) => e.entityType == entityType && e.entityId == entityId)
        .toList()
        .reversed
        .take(limit)
        .toList(),
  );

  @override
  Object snapshot() => List<AuditEntry>.of(entries);

  @override
  void restore(Object snapshot) =>
      entries = List<AuditEntry>.of(snapshot as List<AuditEntry>);
}

class FakeInventoryRepository implements InventoryRepository, Rollbackable {
  FakeInventoryRepository(this.products, this.currency, this.clock);

  final FakeProductRepository products;
  final CurrencyConfig currency;
  final FakeClock clock;

  List<StockMovement> ledger = [];
  Map<String, StockBalance> balances = {};
  Failure? applyFailure;

  Money get _zero => currency.zero();

  @override
  Object snapshot() =>
      (List<StockMovement>.of(ledger), Map<String, StockBalance>.of(balances));

  @override
  void restore(Object snapshot) {
    final (l, b) = snapshot as (List<StockMovement>, Map<String, StockBalance>);
    ledger = List<StockMovement>.of(l);
    balances = Map<String, StockBalance>.of(b);
  }

  StockBalance _balanceOf(String productId) =>
      balances[productId] ??
      StockBalance(
        productId: productId,
        quantityOnHand: Quantity.zero,
        inventoryValue: _zero,
      );

  @override
  Future<Result<List<StockItem>>> listStock(StockFilter filter) async {
    final found = await products.search(
      ProductFilter(
        query: filter.query,
        categoryId: filter.categoryId,
        includeArchived: filter.includeArchived,
      ),
    );
    final list = found.valueOrNull;
    if (list == null) {
      return Result.failure(found.failureOrNull!);
    }
    final items = [
      for (final p in list) StockItem(product: p, balance: _balanceOf(p.id)),
    ].where((i) => filter.status.matches(i.status)).toList();
    return Result.success(items);
  }

  @override
  Future<Result<StockItem>> getStockItem(String productId) async {
    final product = await products.getById(productId);
    final p = product.valueOrNull;
    if (p == null) {
      return Result.failure(product.failureOrNull!);
    }
    return Result.success(
      StockItem(product: p, balance: _balanceOf(productId)),
    );
  }

  @override
  Future<Result<StockBalance>> getBalance(String productId) async =>
      Result.success(_balanceOf(productId));

  @override
  Future<Result<List<StockBalance>>> allBalances() async =>
      Result.success(balances.values.toList());

  @override
  Future<Result<List<StockMovement>>> movements(
    String productId, {
    int limit = 50,
    int offset = 0,
  }) async => Result.success(
    ledger
        .where((m) => m.productId == productId)
        .toList()
        .reversed
        .skip(offset)
        .take(limit)
        .toList(),
  );

  @override
  Future<Result<List<StockMovement>>> movementsForSource(
    String sourceType,
    String sourceId,
  ) async => Result.success(
    ledger
        .where((m) => m.sourceType == sourceType && m.sourceId == sourceId)
        .toList(),
  );

  @override
  Future<Result<bool>> hasMovements(String productId) async =>
      Result.success(ledger.any((m) => m.productId == productId));

  @override
  Future<Result<List<LedgerTotals>>> ledgerTotals() async {
    final byProduct = <String, (Quantity, Money)>{};
    for (final m in ledger) {
      final current = byProduct[m.productId] ?? (Quantity.zero, _zero);
      byProduct[m.productId] = (
        current.$1 + m.quantityDelta,
        current.$2 + m.totalCost,
      );
    }
    return Result.success([
      for (final e in byProduct.entries)
        LedgerTotals(productId: e.key, quantity: e.value.$1, value: e.value.$2),
    ]);
  }

  @override
  Future<Result<InventoryValuation>> valuation() async {
    final listed = await listStock(const StockFilter(includeArchived: true));
    final items = listed.valueOrNull;
    if (items == null) {
      return Result.failure(listed.failureOrNull!);
    }
    var total = _zero;
    var inStock = 0;
    var low = 0;
    var out = 0;
    for (final i in items) {
      total += i.balance.inventoryValue;
      if (i.balance.quantityOnHand.isPositive) {
        inStock++;
      }
      if (!i.product.isArchived) {
        if (i.status == StockStatus.low) low++;
        if (i.status == StockStatus.out) out++;
      }
    }
    return Result.success(
      InventoryValuation(
        totalValue: total,
        productsInStock: inStock,
        lowStockCount: low,
        outOfStockCount: out,
      ),
    );
  }

  @override
  Future<Result<void>> applyMovement(
    StockMovement movement,
    StockPosition newPosition,
  ) async {
    if (applyFailure != null) {
      return Result.failure(applyFailure!);
    }
    ledger.add(movement);
    balances[movement.productId] = StockBalance(
      productId: movement.productId,
      quantityOnHand: newPosition.quantity,
      inventoryValue: newPosition.value,
      updatedAt: movement.createdAt,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> replaceBalance(
    String productId,
    StockPosition position,
    DateTime at,
  ) async {
    balances[productId] = StockBalance(
      productId: productId,
      quantityOnHand: position.quantity,
      inventoryValue: position.value,
      updatedAt: at,
    );
    return const Result.success(null);
  }
}
