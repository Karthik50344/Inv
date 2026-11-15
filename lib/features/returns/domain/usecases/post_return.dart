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
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/returns/domain/entities/return_document.dart';
import 'package:inventrix/features/returns/domain/entities/return_input.dart';
import 'package:inventrix/features/returns/domain/entities/return_line.dart';
import 'package:inventrix/features/returns/domain/entities/return_numbering.dart';
import 'package:inventrix/features/returns/domain/entities/returnable_invoice.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/features/returns/domain/services/return_planner.dart';
import 'package:inventrix/features/returns/domain/services/returnable_invoice_loader.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';
import 'package:inventrix/shared/domain/audit/audit_log_repository.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/services/document_number.dart';
import 'package:inventrix/shared/domain/services/document_sequence_repository.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Posts a sales or purchase return in one transaction.
///
/// Everything is re-validated inside the transaction (UI state is advisory):
/// the invoice must be posted, every quantity must fit what has not been
/// returned yet, and the cash refund must not exceed the money the party
/// has paid beyond what they still owe.
///
/// - **Sales return:** each line may go back into stock (`restock`) at the
///   cost it left with; damaged goods are returned without a stock movement.
/// - **Purchase return:** each line leaves stock at the current average
///   cost; if less is on hand than is being returned, the whole return is
///   rejected with `InsufficientStockFailure` and nothing changes.
///
/// The return is a credit note: it lowers what is owed. Cash handed back is
/// recorded on the return itself. The original invoice is never touched.
/// Posting the same idempotency key twice returns the first result.
final class PostReturn {
  /// Creates the use case.
  const PostReturn({
    required ReturnableInvoiceLoader loader,
    required ReturnRepository returns,
    required InventoryRepository inventory,
    required PaymentMethodRepository methods,
    required DocumentSequenceRepository sequences,
    required AuditLogRepository audit,
    required TransactionRunner transactions,
    required IdGenerator ids,
    required Clock clock,
  }) : _loader = loader,
       _returns = returns,
       _inventory = inventory,
       _methods = methods,
       _sequences = sequences,
       _audit = audit,
       _transactions = transactions,
       _ids = ids,
       _clock = clock;

  final ReturnableInvoiceLoader _loader;
  final ReturnRepository _returns;
  final InventoryRepository _inventory;
  final PaymentMethodRepository _methods;
  final DocumentSequenceRepository _sequences;
  final AuditLogRepository _audit;
  final TransactionRunner _transactions;
  final IdGenerator _ids;
  final Clock _clock;

  /// Posts the return described by [input].
  ///
  /// Field errors use the keys `reason`, `notes`, `returnDate`, `refund`,
  /// `refundMethod` and `line:<invoice line id>`.
  Future<Result<ReturnDocument>> call(ReturnInput input) async {
    final reasonError = Validators.requiredText(
      input.reason,
      label: 'Reason',
      maxLength: 200,
    );
    if (reasonError != null) {
      return Result.failure(
        ValidationFailure(reasonError, fieldErrors: {'reason': reasonError}),
      );
    }
    final notesError = Validators.optionalText(
      input.notes,
      label: 'Notes',
      maxLength: 500,
    );
    if (notesError != null) {
      return Result.failure(
        ValidationFailure(notesError, fieldErrors: {'notes': notesError}),
      );
    }
    final date = input.returnDate;
    if (date == null) {
      return const Result.failure(
        ValidationFailure(
          'Return date is required.',
          fieldErrors: {'returnDate': 'Return date is required.'},
        ),
      );
    }
    final key = input.idempotencyKey.trim();
    if (key.isEmpty) {
      return const Result.failure(
        ValidationFailure('A return needs an idempotency key.'),
      );
    }
    final returnDate = DateTime.utc(date.year, date.month, date.day);
    final reason = input.reason.trim();
    final notes = blankToNull(input.notes);

    return _transactions.runResult(() async {
      final existing = (await _returns.findByIdempotencyKey(
        input.kind,
        key,
      )).getOrThrow();
      if (existing != null) {
        if (existing.invoiceId != input.invoiceId) {
          throw const FailureException(
            ValidationFailure(
              'This return key was already used for a different return.',
            ),
          );
        }
        return existing;
      }

      final invoice = await _loader.require(input.kind, input.invoiceId);
      final invoiceDay = DateTime.utc(
        invoice.invoiceDate.year,
        invoice.invoiceDate.month,
        invoice.invoiceDate.day,
      );
      if (returnDate.isBefore(invoiceDay)) {
        throw const FailureException(
          ValidationFailure(
            'The return date cannot be before the invoice date.',
            fieldErrors: {
              'returnDate': 'Cannot be before the invoice date.',
            },
          ),
        );
      }

      final plan = ReturnPlanner.plan(invoice, input.lines);
      if (plan.lineErrors.isNotEmpty) {
        throw FailureException(
          ValidationFailure(
            plan.lineErrors.values.first,
            fieldErrors: {
              for (final e in plan.lineErrors.entries) 'line:${e.key}': e.value,
            },
          ),
        );
      }
      if (plan.lines.isEmpty) {
        throw const FailureException(
          ValidationFailure('Choose at least one item to return.'),
        );
      }
      for (final planned in plan.lines) {
        if (invoice.kind == InvoiceKind.sales &&
            planned.restock &&
            planned.stockCost == null) {
          throw FailureException(
            ValidationFailure(
              'The stock record of ${planned.line.productName} is missing, '
              'so it cannot be put back into stock. Return it without '
              'restocking.',
            ),
          );
        }
      }

      final refund = await _planRefund(invoice, plan.total, input);

      final now = _clock.now();
      final sequence = (await _sequences.next(
        ReturnNumbering.sequenceKey(input.kind),
      )).getOrThrow();
      final number = DocumentNumber.format(
        ReturnNumbering.prefix(input.kind),
        sequence,
      );
      final returnId = _ids.newId();

      final lines = <ReturnLine>[];
      var lineNo = 0;
      for (final planned in plan.lines) {
        lineNo++;
        final lineId = _ids.newId();
        final stockCost = await _moveStock(
          invoice: invoice,
          planned: planned,
          number: number,
          reason: reason,
          returnId: returnId,
          lineId: lineId,
          now: now,
        );
        lines.add(
          ReturnLine(
            id: lineId,
            lineNo: lineNo,
            invoiceLineId: planned.line.invoiceLineId,
            productId: planned.line.productId,
            productName: planned.line.productName,
            sku: planned.line.sku,
            unitSymbol: planned.line.unitSymbol,
            unitDecimalPlaces: planned.line.unitDecimalPlaces,
            quantity: planned.quantity,
            net: planned.net,
            tax: planned.tax,
            restocked: planned.restock,
            stockCost: stockCost,
            note: planned.note,
          ),
        );
      }

      final document = ReturnDocument(
        id: returnId,
        kind: input.kind,
        number: number,
        invoiceId: invoice.invoiceId,
        invoiceNumber: invoice.invoiceNumber,
        partyId: invoice.partyId,
        partyName: invoice.partyName,
        returnDate: returnDate,
        reason: reason,
        notes: notes,
        lines: lines,
        refund: refund,
        idempotencyKey: key,
        createdAt: now,
      );
      (await _returns.insert(document)).getOrThrow();
      (await _audit.record(
        AuditEntry(
          id: _ids.newId(),
          entityType: ReturnNumbering.sourceType(input.kind),
          entityId: returnId,
          action: 'posted',
          summary:
              'Posted $number against ${invoice.invoiceNumber}: '
              '${lines.length} line(s), total ${document.total}'
              '${refund == null ? '' : ', refunded ${refund.amount}'}. '
              'Reason: $reason',
          occurredAt: now,
        ),
      )).getOrThrow();
      return (await _returns.getById(input.kind, returnId)).getOrThrow();
    });
  }

  /// Decides how much of the return is paid out in cash.
  ///
  /// A return of a walk-in sale has no account to credit, so its whole
  /// value is handed back. For everyone else the cash refund is whatever
  /// the user asked for (default none), up to the money paid beyond what
  /// is still owed; the rest stays as credit on the account.
  Future<ReturnRefund?> _planRefund(
    ReturnableInvoice invoice,
    Money total,
    ReturnInput input,
  ) async {
    final Money amount;
    if (invoice.isWalkIn) {
      amount = total;
    } else {
      final text = input.refundAmount.trim();
      if (text.isEmpty) {
        amount = invoice.zero;
      } else {
        final parsed = Money.tryParse(
          text,
          currencyCode: invoice.zero.currencyCode,
          decimalPlaces: invoice.zero.decimalPlaces,
        );
        if (parsed == null || parsed.isNegative) {
          throw const FailureException(
            ValidationFailure(
              'Enter a valid refund amount.',
              fieldErrors: {'refund': 'Enter a valid amount.'},
            ),
          );
        }
        amount = parsed;
      }
    }
    if (!amount.isPositive) {
      return null;
    }
    final capacity = invoice.refundCapacity(total);
    if (amount > capacity) {
      final message = capacity.isPositive
          ? 'At most ${capacity.toPlainString()} can be refunded in cash: '
                'only that much has been paid beyond what is still owed. '
                'The rest stays as credit.'
          : 'Nothing has been paid beyond what is still owed, so there is '
                'nothing to refund in cash. The value stays as credit.';
      throw FailureException(
        ValidationFailure(message, fieldErrors: {'refund': message}),
      );
    }
    final methodId = input.refundMethodId;
    if (methodId == null || methodId.isEmpty) {
      throw const FailureException(
        ValidationFailure(
          'Choose how the money is handed back.',
          fieldErrors: {'refundMethod': 'Choose a payment method.'},
        ),
      );
    }
    final method = (await _methods.getById(methodId)).getOrThrow();
    if (method.isArchived) {
      throw FailureException(
        ValidationFailure(
          '${method.name} is archived. Choose another payment method.',
          fieldErrors: {'refundMethod': 'This method is archived.'},
        ),
      );
    }
    return ReturnRefund(
      amount: amount,
      methodId: method.id,
      methodName: method.name,
      reference: blankToNull(input.refundReference),
    );
  }

  /// Moves stock for one planned line and returns the value that moved
  /// (zero when nothing moved).
  Future<Money> _moveStock({
    required ReturnableInvoice invoice,
    required PlannedReturnLine planned,
    required String number,
    required String reason,
    required String returnId,
    required String lineId,
    required DateTime now,
  }) async {
    final line = planned.line;
    final balance = (await _inventory.getBalance(line.productId)).getOrThrow();
    switch (invoice.kind) {
      case InvoiceKind.sales:
        if (!planned.restock) {
          return invoice.zero;
        }
        final cost = planned.stockCost!;
        final posting = StockCalculator.stockIn(
          balance.position,
          planned.quantity,
          cost,
        );
        (await _inventory.applyMovement(
          StockMovement(
            id: _ids.newId(),
            productId: line.productId,
            type: StockMovementType.salesReturn,
            quantityDelta: posting.quantityDelta,
            totalCost: posting.costDelta,
            unitCost: cost.perUnit(planned.quantity),
            sourceType: ReturnNumbering.sourceType(invoice.kind),
            sourceId: returnId,
            sourceLineId: lineId,
            reason: 'Return $number: $reason',
            occurredAt: now,
            createdAt: now,
          ),
          posting.position,
        )).getOrThrow();
        return cost;
      case InvoiceKind.purchase:
        final result = StockCalculator.stockOut(
          productId: line.productId,
          position: balance.position,
          quantity: planned.quantity,
        );
        final posting = result.valueOrNull;
        if (posting == null) {
          throw FailureException(_describeShortage(result.failureOrNull!, line));
        }
        final cost = posting.costDelta.abs();
        (await _inventory.applyMovement(
          StockMovement(
            id: _ids.newId(),
            productId: line.productId,
            type: StockMovementType.purchaseReturn,
            quantityDelta: posting.quantityDelta,
            totalCost: posting.costDelta,
            unitCost: cost.perUnit(planned.quantity),
            sourceType: ReturnNumbering.sourceType(invoice.kind),
            sourceId: returnId,
            sourceLineId: lineId,
            reason: 'Return $number: $reason',
            occurredAt: now,
            createdAt: now,
          ),
          posting.position,
        )).getOrThrow();
        return cost;
    }
  }

  /// Names the product in a stock shortage so the user knows which line to
  /// fix.
  Failure _describeShortage(Failure failure, ReturnableLine line) {
    if (failure is! InsufficientStockFailure) {
      return failure;
    }
    final available = Quantity.fromMilli(failure.availableMilli);
    return InsufficientStockFailure(
      'Not enough ${line.productName} in stock to send back: '
      '${available.toDecimalString()} ${line.unitSymbol} on hand, '
      '${Quantity.fromMilli(failure.requestedMilli).toDecimalString()} '
      '${line.unitSymbol} to return.',
      productId: failure.productId,
      requestedMilli: failure.requestedMilli,
      availableMilli: failure.availableMilli,
    );
  }
}
