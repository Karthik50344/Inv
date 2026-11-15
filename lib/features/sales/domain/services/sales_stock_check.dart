import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Checks that the quantities on a sales invoice can be served from stock.
///
/// Lines are checked cumulatively per product: two lines of 6 for a product
/// with 10 in stock fail on the second line. This is the user-facing check
/// when a draft is saved; posting re-checks against the stock ledger inside
/// its transaction and is the authoritative one.
final class SalesStockCheck {
  /// Creates the check.
  const SalesStockCheck({required InventoryRepository inventory})
    : _inventory = inventory;

  final InventoryRepository _inventory;

  /// Returns, per line index, a message for every line that cannot be served.
  /// An empty map means all lines are available.
  Future<Result<Map<int, String>>> findShortages(
    List<SalesLine> lines,
  ) async {
    final onHand = <String, Quantity>{};
    final requested = <String, Quantity>{};
    final shortages = <int, String>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final productId = line.productId;
      if (!onHand.containsKey(productId)) {
        final balance = await _inventory.getBalance(productId);
        final found = balance.valueOrNull;
        if (found == null) {
          return Result.failure(balance.failureOrNull!);
        }
        onHand[productId] = found.quantityOnHand;
      }
      final total = (requested[productId] ?? Quantity.zero) + line.quantity;
      requested[productId] = total;
      final available = onHand[productId]!;
      if (total > available) {
        shortages[i] = message(
          productName: line.productName,
          unitSymbol: line.unitSymbol,
          available: available,
          requested: total,
        );
      }
    }
    return Result.success(shortages);
  }

  /// The message shown for a shortage.
  static String message({
    required String productName,
    required String unitSymbol,
    required Quantity available,
    required Quantity requested,
  }) =>
      'Only ${available.toDecimalString()} $unitSymbol of $productName in '
      'stock, but ${requested.toDecimalString()} $unitSymbol requested.';
}
