import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/services/stock_calculator.dart';
import 'package:inventrix/features/inventory/domain/services/stock_operation_support.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Direction of a manual stock adjustment.
enum StockAdjustmentDirection { stockIn, stockOut }

/// Manually adds or removes stock with a mandatory reason.
///
/// Stock-out values the removed units at the current weighted average cost.
/// Stock-in uses the given unit cost, else the current average cost, else the
/// product's purchase price.
final class AdjustStock {
  /// Creates the use case.
  const AdjustStock({
    required StockOperationSupport support,
    required InventoryRepository inventory,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _support = support,
       _inventory = inventory,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final StockOperationSupport _support;
  final InventoryRepository _inventory;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Applies the adjustment. Insufficient stock fails with
  /// `InsufficientStockFailure` and changes nothing.
  Future<Result<StockMovement>> call({
    required String productId,
    required StockAdjustmentDirection direction,
    required String quantity,
    required String reason,
    String unitCost = '',
  }) async {
    final loaded = await _support.load(productId);
    final context = loaded.valueOrNull;
    if (context == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    final errors = FieldErrors()
      ..add(
        'reason',
        Validators.requiredText(reason, label: 'Reason', maxLength: 200),
      );
    final qty = _support.parseQuantity(quantity, context.unit, errors);
    final cost = direction == StockAdjustmentDirection.stockIn
        ? _support.parseUnitCost(unitCost, context.currency, errors)
        : null;
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final amount = qty!;
    final trimmedReason = reason.trim();

    return _transactions.runResult(() async {
      // Re-read the balance inside the transaction: UI state is advisory.
      final balance = (await _inventory.getBalance(productId)).getOrThrow();
      final StockPosting posting;
      final StockMovementType type;
      if (direction == StockAdjustmentDirection.stockIn) {
        type = StockMovementType.adjustmentIn;
        posting = StockCalculator.stockIn(
          balance.position,
          amount,
          _inboundCost(
            balance: balance,
            amount: amount,
            unitCost: cost,
            purchasePrice: context.product.purchasePrice,
          ),
        );
      } else {
        type = StockMovementType.adjustmentOut;
        posting = StockCalculator.stockOut(
          productId: productId,
          position: balance.position,
          quantity: amount,
        ).getOrThrow();
      }
      final now = _clock.now();
      final movement = StockMovement(
        id: _ids.newId(),
        productId: productId,
        type: type,
        quantityDelta: posting.quantityDelta,
        totalCost: posting.costDelta,
        unitCost: posting.costDelta.abs().perUnit(amount),
        reason: trimmedReason,
        occurredAt: now,
        createdAt: now,
      );
      (await _inventory.applyMovement(movement, posting.position)).getOrThrow();
      final verb = direction == StockAdjustmentDirection.stockIn ? 'in' : 'out';
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: 'stock',
          entityId: productId,
          action: type.dbName,
          summary:
              'Stock $verb ${amount.toDecimalString()} '
              '${context.unit.symbol} for ${context.product.sku}: '
              '$trimmedReason',
          occurredAt: now,
        ),
      )).getOrThrow();
      return movement;
    });
  }

  /// Total cost of an inbound adjustment: the given unit cost, else the
  /// current average cost, else the product's purchase price.
  Money _inboundCost({
    required StockBalance balance,
    required Quantity amount,
    required Money? unitCost,
    required Money purchasePrice,
  }) {
    final unit = unitCost ?? balance.averageCost ?? purchasePrice;
    return unit.multiplyByQuantity(amount);
  }
}
