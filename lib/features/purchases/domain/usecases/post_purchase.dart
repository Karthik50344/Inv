import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/services/stock_calculator.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/purchases/domain/services/purchase_integrity.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';

/// Posts a purchase: assigns its number, marks it posted and adds every line
/// to stock at its net cost (weighted average cost), all in one transaction.
///
/// Everything is re-validated inside the transaction: UI state is advisory.
/// A second post of the same invoice fails (its status is no longer
/// postable, and the ledger's unique source index would reject duplicate
/// movements), so stock can never be received twice.
final class PostPurchase {
  /// Creates the use case.
  const PostPurchase({
    required PurchaseRepository purchases,
    required SupplierRepository suppliers,
    required ProductRepository products,
    required InventoryRepository inventory,
    required DocumentSequenceRepository sequences,
    required SettingsRepository settings,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _purchases = purchases,
       _suppliers = suppliers,
       _products = products,
       _inventory = inventory,
       _sequences = sequences,
       _settings = settings,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final PurchaseRepository _purchases;
  final SupplierRepository _suppliers;
  final ProductRepository _products;
  final InventoryRepository _inventory;
  final DocumentSequenceRepository _sequences;
  final SettingsRepository _settings;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Posts purchase [id] and returns the posted invoice.
  Future<Result<PurchaseInvoice>> call(
    String id,
  ) => _transactions.runResult(() async {
    // 1. Validate the document and its status.
    final invoice = (await _purchases.getById(id)).getOrThrow();
    final approvalRequired = (await _settings.isPurchaseApprovalRequired())
        .getOrThrow();
    _requirePostable(invoice, approvalRequired: approvalRequired);
    final problem = PurchaseIntegrity.findProblem(invoice);
    if (problem != null) {
      throw FailureException(ValidationFailure(problem));
    }

    // 2. Validate the supplier and every product.
    final supplier = (await _suppliers.getById(
      invoice.supplierId,
    )).getOrThrow();
    if (supplier.isArchived) {
      throw FailureException(
        ValidationFailure(
          '${supplier.name} is archived. Restore the supplier first.',
        ),
      );
    }
    for (final line in invoice.lines) {
      final product = (await _products.getById(line.productId)).getOrThrow();
      if (product.isArchived) {
        throw FailureException(
          ValidationFailure(
            '${product.name} is archived. Restore it or remove the line.',
          ),
        );
      }
    }

    // 3. Number, status, stock, audit: all inside this transaction.
    final now = _clock.now();
    final sequence = (await _sequences.next(
      PurchaseNumbering.sequenceKey,
    )).getOrThrow();
    final number = DocumentNumber.format(PurchaseNumbering.prefix, sequence);
    (await _purchases.markPosted(id, number: number, at: now)).getOrThrow();

    for (final line in invoice.lines) {
      // Re-read per line: several lines may share a product.
      final balance = (await _inventory.getBalance(
        line.productId,
      )).getOrThrow();
      final posting = StockCalculator.stockIn(
        balance.position,
        line.quantity,
        line.net,
      );
      final movement = StockMovement(
        id: _ids.newId(),
        productId: line.productId,
        type: StockMovementType.purchase,
        quantityDelta: posting.quantityDelta,
        totalCost: posting.costDelta,
        unitCost: posting.costDelta.perUnit(line.quantity),
        sourceType: PurchaseNumbering.sourceType,
        sourceId: id,
        sourceLineId: line.id,
        occurredAt: now,
        createdAt: now,
      );
      (await _inventory.applyMovement(movement, posting.position)).getOrThrow();
    }

    (await _audit.record(
      AuditEntry(
        id: _ids.newId(),
        entityType: PurchaseNumbering.sourceType,
        entityId: id,
        action: 'posted',
        summary:
            'Posted $number from ${invoice.supplierName}: '
            '${invoice.lines.length} line(s), total ${invoice.totals.total}',
        occurredAt: now,
      ),
    )).getOrThrow();
    return (await _purchases.getById(id)).getOrThrow();
  });

  void _requirePostable(
    PurchaseInvoice invoice, {
    required bool approvalRequired,
  }) {
    if (invoice.status == DocumentStatus.posted) {
      throw const FailureException(
        ValidationFailure('This purchase is already posted.'),
      );
    }
    if (!invoice.status.canTransitionTo(DocumentStatus.posted)) {
      throw FailureException(
        ValidationFailure(
          'A ${invoice.status.label.toLowerCase()} purchase cannot be posted.',
        ),
      );
    }
    final needsApproval =
        approvalRequired &&
        invoice.status != DocumentStatus.approved &&
        invoice.status != DocumentStatus.authorized;
    if (needsApproval) {
      throw const FailureException(
        ValidationFailure(
          'Purchases must be approved before they can be posted.',
        ),
      );
    }
  }
}
