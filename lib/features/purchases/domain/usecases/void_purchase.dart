import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/services/stock_calculator.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/services/invoice_payment_guard.dart';
import 'package:inventrix/shared/domain/services/invoice_return_lookup.dart';

/// Voids a posted purchase through compensating `reversal` stock movements.
///
/// The posted document and its original movements stay untouched; the void
/// is a new set of ledger entries. If any part of the received stock has
/// already left (for example it was sold) the void is rejected with
/// `InsufficientStockFailure` and nothing changes: stock never goes
/// negative.
///
/// A purchase with payments allocated (Phase 6) or returns recorded against
/// it (Phase 7) cannot be voided: reverse the payments first; a return is
/// final, so the invoice stays as it is.
final class VoidPurchase {
  /// Creates the use case.
  const VoidPurchase({
    required PurchaseRepository purchases,
    required InventoryRepository inventory,
    required AuditLogRepository audit,
    required InvoicePaymentGuard payments,
    required InvoiceReturnGuard returns,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _purchases = purchases,
       _inventory = inventory,
       _audit = audit,
       _payments = payments,
       _returns = returns,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final PurchaseRepository _purchases;
  final InventoryRepository _inventory;
  final AuditLogRepository _audit;
  final InvoicePaymentGuard _payments;
  final InvoiceReturnGuard _returns;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Voids purchase [id]; a [reason] is mandatory.
  Future<Result<PurchaseInvoice>> call(
    String id, {
    required String reason,
  }) async {
    final reasonError = Validators.requiredText(
      reason,
      label: 'Reason',
      maxLength: 200,
    );
    if (reasonError != null) {
      return Result.failure(
        ValidationFailure(reasonError, fieldErrors: {'reason': reasonError}),
      );
    }
    final trimmed = reason.trim();
    return _transactions.runResult(() async {
      final invoice = (await _purchases.getById(id)).getOrThrow();
      if (invoice.status != DocumentStatus.posted) {
        throw FailureException(
          ValidationFailure(
            'Only posted purchases can be voided '
            '(this one is ${invoice.status.label.toLowerCase()}).',
          ),
        );
      }
      final settled = (await _payments.hasActivePayments(
        InvoiceKind.purchase,
        id,
      )).getOrThrow();
      if (settled) {
        throw FailureException(
          ValidationFailure(
            '${invoice.displayNumber} has payments allocated to it. '
            'Reverse those payments before voiding the purchase.',
          ),
        );
      }
      final returned = (await _returns.hasReturns(
        InvoiceKind.purchase,
        id,
      )).getOrThrow();
      if (returned) {
        throw FailureException(
          ValidationFailure(
            '${invoice.displayNumber} has returns recorded against it, so '
            'it cannot be voided.',
          ),
        );
      }
      final now = _clock.now();
      (await _purchases.markVoided(id, reason: trimmed, at: now)).getOrThrow();

      for (final line in invoice.lines.reversed) {
        final balance = (await _inventory.getBalance(
          line.productId,
        )).getOrThrow();
        final posting = StockCalculator.removeReceived(
          productId: line.productId,
          position: balance.position,
          quantity: line.quantity,
          originalCost: line.net,
        ).getOrThrow();
        final movement = StockMovement(
          id: _ids.newId(),
          productId: line.productId,
          type: StockMovementType.reversal,
          quantityDelta: posting.quantityDelta,
          totalCost: posting.costDelta,
          unitCost: posting.costDelta.abs().perUnit(line.quantity),
          sourceType: PurchaseNumbering.sourceType,
          sourceId: id,
          sourceLineId: line.id,
          reason: 'Void of ${invoice.displayNumber}: $trimmed',
          occurredAt: now,
          createdAt: now,
        );
        (await _inventory.applyMovement(
          movement,
          posting.position,
        )).getOrThrow();
      }

      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: PurchaseNumbering.sourceType,
          entityId: id,
          action: 'voided',
          summary: 'Voided ${invoice.displayNumber}: $trimmed',
          occurredAt: now,
          reason: trimmed,
          previousValues: const {'status': 'posted'},
          newValues: const {'status': 'voided'},
        ),
      )).getOrThrow();
      return (await _purchases.getById(id)).getOrThrow();
    });
  }
}
