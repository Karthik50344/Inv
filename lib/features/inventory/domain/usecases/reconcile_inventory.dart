import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/inventory/domain/entities/reconciliation.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Compares every maintained balance with the sums of the stock ledger.
///
/// The ledger is the source of truth; this never changes data.
final class ReconcileInventory {
  /// Creates the use case.
  const ReconcileInventory({required InventoryRepository inventory})
    : _inventory = inventory;

  final InventoryRepository _inventory;

  /// Produces the report.
  Future<Result<ReconciliationReport>> call() async {
    final totalsResult = await _inventory.ledgerTotals();
    final totals = totalsResult.valueOrNull;
    if (totals == null) {
      return Result.failure(totalsResult.failureOrNull!);
    }
    final balancesResult = await _inventory.allBalances();
    final balances = balancesResult.valueOrNull;
    if (balances == null) {
      return Result.failure(balancesResult.failureOrNull!);
    }
    final ledger = {for (final t in totals) t.productId: t};
    final stored = {for (final b in balances) b.productId: b};
    final ids = {...ledger.keys, ...stored.keys}.toList()..sort();

    final mismatches = <BalanceMismatch>[];
    for (final id in ids) {
      final expected = ledger[id];
      final actual = stored[id];
      final zero = _zeroLike(expected, actual);
      final expectedQty = expected?.quantity ?? Quantity.zero;
      final expectedValue = expected?.value ?? zero;
      final actualQty = actual?.quantityOnHand ?? Quantity.zero;
      final actualValue = actual?.inventoryValue ?? zero;
      final missing = actual == null && expected != null;
      if (missing || expectedQty != actualQty || expectedValue != actualValue) {
        // A missing balance for a ledger that nets to zero is harmless.
        if (missing && expectedQty.isZero && expectedValue.isZero) {
          continue;
        }
        mismatches.add(
          BalanceMismatch(
            productId: id,
            expectedQuantity: expectedQty,
            expectedValue: expectedValue,
            actualQuantity: actualQty,
            actualValue: actualValue,
            balanceMissing: actual == null,
          ),
        );
      }
    }
    return Result.success(
      ReconciliationReport(productsChecked: ids.length, mismatches: mismatches),
    );
  }

  Money _zeroLike(LedgerTotals? totals, StockBalance? balance) {
    final reference = totals?.value ?? balance!.inventoryValue;
    return Money.zero(
      currencyCode: reference.currencyCode,
      decimalPlaces: reference.decimalPlaces,
    );
  }
}
