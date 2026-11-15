import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_position.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/usecases/reconcile_inventory.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Rewrites mismatching balances from the ledger (the source of truth).
///
/// This is an explicit, audited repair: each corrected product gets an audit
/// entry, and everything happens in one transaction. A ledger that nets to a
/// negative quantity or value is never "repaired" — that needs manual review.
final class RepairInventoryBalances {
  /// Creates the use case.
  const RepairInventoryBalances({
    required ReconcileInventory reconcile,
    required InventoryRepository inventory,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _reconcile = reconcile,
       _inventory = inventory,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final ReconcileInventory _reconcile;
  final InventoryRepository _inventory;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Repairs all mismatches and returns how many balances were corrected.
  Future<Result<int>> call() {
    return _transactions.runResult(() async {
      final report = (await _reconcile()).getOrThrow();
      if (report.isConsistent) {
        return 0;
      }
      for (final mismatch in report.mismatches) {
        if (mismatch.expectedQuantity.isNegative ||
            mismatch.expectedValue.isNegative) {
          throw FailureException(
            ValidationFailure(
              'The ledger of product ${mismatch.productId} nets to a '
              'negative amount. This needs manual review and was not '
              'repaired.',
            ),
          );
        }
      }
      final now = _clock.now();
      for (final mismatch in report.mismatches) {
        (await _inventory.replaceBalance(
          mismatch.productId,
          StockPosition(
            quantity: mismatch.expectedQuantity,
            value: mismatch.expectedValue,
          ),
          now,
        )).getOrThrow();
        (await _audit.record(
          AuditEntry(
            id: _ids.newId(),
            entityType: 'stock',
            entityId: mismatch.productId,
            action: 'balance_repaired',
            summary:
                'Balance corrected from ledger: quantity '
                '${mismatch.actualQuantity.toDecimalString()} -> '
                '${mismatch.expectedQuantity.toDecimalString()}, value '
                '${mismatch.actualValue.toPlainString()} -> '
                '${mismatch.expectedValue.toPlainString()}',
            occurredAt: now,
          ),
        )).getOrThrow();
      }
      return report.mismatches.length;
    });
  }
}
