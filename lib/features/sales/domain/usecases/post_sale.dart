import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement_type.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/inventory/domain/services/stock_calculator.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/sales/domain/services/sales_integrity.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Posts a sale: assigns its number, marks it posted and takes every line
/// out of stock at the current weighted average cost, all in one
/// transaction.
///
/// Everything is re-validated inside the transaction: UI state is advisory.
/// Stock is read from the ledger projection per line, so several lines of
/// one product are checked cumulatively; if any line cannot be served the
/// whole posting rolls back with `InsufficientStockFailure` and stock never
/// goes negative. A second post of the same invoice fails (its status is no
/// longer postable, and the ledger's unique source index would reject
/// duplicate movements), so stock can never be issued twice.
final class PostSale {
  /// Creates the use case.
  const PostSale({
    required SalesRepository sales,
    required CustomerRepository customers,
    required ProductRepository products,
    required InventoryRepository inventory,
    required DocumentSequenceRepository sequences,
    required SettingsRepository settings,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _sales = sales,
       _customers = customers,
       _products = products,
       _inventory = inventory,
       _sequences = sequences,
       _settings = settings,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final SalesRepository _sales;
  final CustomerRepository _customers;
  final ProductRepository _products;
  final InventoryRepository _inventory;
  final DocumentSequenceRepository _sequences;
  final SettingsRepository _settings;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Posts sale [id] and returns the posted invoice.
  Future<Result<SalesInvoice>> call(
    String id,
  ) => _transactions.runResult(() async {
    // 1. Validate the document and its status.
    final invoice = (await _sales.getById(id)).getOrThrow();
    final approvalRequired = (await _settings.isSalesApprovalRequired())
        .getOrThrow();
    _requirePostable(invoice, approvalRequired: approvalRequired);
    final problem = SalesIntegrity.findProblem(invoice);
    if (problem != null) {
      throw FailureException(ValidationFailure(problem));
    }

    // 2. Validate the customer (if any) and every product.
    final customerId = invoice.customerId;
    if (customerId != null) {
      final customer = (await _customers.getById(customerId)).getOrThrow();
      if (customer.isArchived) {
        throw FailureException(
          ValidationFailure(
            '${customer.name} is archived. Restore the customer first.',
          ),
        );
      }
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
      SalesNumbering.sequenceKey,
    )).getOrThrow();
    final number = DocumentNumber.format(SalesNumbering.prefix, sequence);
    (await _sales.markPosted(id, number: number, at: now)).getOrThrow();

    for (final line in invoice.lines) {
      // Re-read per line: several lines may share a product.
      final balance = (await _inventory.getBalance(
        line.productId,
      )).getOrThrow();
      final result = StockCalculator.stockOut(
        productId: line.productId,
        position: balance.position,
        quantity: line.quantity,
      );
      final posting = result.valueOrNull;
      if (posting == null) {
        throw FailureException(_describeShortage(result.failureOrNull!, line));
      }
      final movement = StockMovement(
        id: _ids.newId(),
        productId: line.productId,
        type: StockMovementType.sale,
        quantityDelta: posting.quantityDelta,
        totalCost: posting.costDelta,
        unitCost: posting.costDelta.abs().perUnit(line.quantity),
        sourceType: SalesNumbering.sourceType,
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
        entityType: SalesNumbering.sourceType,
        entityId: id,
        action: 'posted',
        summary:
            'Posted $number to ${invoice.customerName}: '
            '${invoice.lines.length} line(s), total ${invoice.totals.total}',
        occurredAt: now,
      ),
    )).getOrThrow();
    return (await _sales.getById(id)).getOrThrow();
  });

  /// Names the product in a stock shortage so the user knows which line to
  /// fix.
  Failure _describeShortage(Failure failure, SalesLine line) {
    if (failure is! InsufficientStockFailure) {
      return failure;
    }
    return InsufficientStockFailure(
      'Not enough ${line.productName} in stock: '
      '${Quantity.fromMilli(failure.availableMilli).toDecimalString()} '
      '${line.unitSymbol} available, '
      '${line.quantity.toDecimalString()} ${line.unitSymbol} needed.',
      productId: failure.productId,
      requestedMilli: failure.requestedMilli,
      availableMilli: failure.availableMilli,
    );
  }

  void _requirePostable(
    SalesInvoice invoice, {
    required bool approvalRequired,
  }) {
    if (invoice.status == DocumentStatus.posted) {
      throw const FailureException(
        ValidationFailure('This sale is already posted.'),
      );
    }
    if (!invoice.status.canTransitionTo(DocumentStatus.posted)) {
      throw FailureException(
        ValidationFailure(
          'A ${invoice.status.label.toLowerCase()} sale cannot be posted.',
        ),
      );
    }
    final needsApproval =
        approvalRequired &&
        invoice.status != DocumentStatus.approved &&
        invoice.status != DocumentStatus.authorized;
    if (needsApproval) {
      throw const FailureException(
        ValidationFailure('Sales must be approved before they can be posted.'),
      );
    }
  }
}
