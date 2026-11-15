import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/services/stock_calculator.dart';
import 'package:inventrix/features/inventory/domain/services/stock_operation_support.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';

/// Records the opening stock of a product.
///
/// Opening stock is allowed only once and only before any other movement, so
/// the ledger always starts with an auditable opening entry.
final class RecordOpeningStock {
  /// Creates the use case.
  const RecordOpeningStock({
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

  /// Records [quantity] on hand for [productId]. [unitCost] defaults to the
  /// product's purchase price when blank.
  Future<Result<StockMovement>> call({
    required String productId,
    required String quantity,
    String unitCost = '',
  }) async {
    final loaded = await _support.load(productId);
    final context = loaded.valueOrNull;
    if (context == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    final errors = FieldErrors();
    final qty = _support.parseQuantity(quantity, context.unit, errors);
    final cost = _support.parseUnitCost(unitCost, context.currency, errors);
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }
    final unitPrice = cost ?? context.product.purchasePrice;
    final totalCost = unitPrice.multiplyByQuantity(qty!);

    return _transactions.runResult(() async {
      if ((await _inventory.hasMovements(productId)).getOrThrow()) {
        throw const FailureException(
          ValidationFailure(
            'Opening stock can only be recorded once, before any other '
            'stock movement.',
          ),
        );
      }
      final balance = (await _inventory.getBalance(productId)).getOrThrow();
      final posting = StockCalculator.stockIn(balance.position, qty, totalCost);
      final now = _clock.now();
      final movement = StockMovement(
        id: _ids.newId(),
        productId: productId,
        type: StockMovementType.openingStock,
        quantityDelta: posting.quantityDelta,
        totalCost: posting.costDelta,
        unitCost: totalCost.perUnit(qty),
        reason: 'Opening stock',
        occurredAt: now,
        createdAt: now,
      );
      (await _inventory.applyMovement(movement, posting.position)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: 'stock',
          entityId: productId,
          action: 'opening_stock',
          summary:
              'Opening stock ${qty.toDecimalString()} '
              '${context.unit.symbol} for ${context.product.sku}',
          occurredAt: now,
        ),
      )).getOrThrow();
      return movement;
    });
  }
}
