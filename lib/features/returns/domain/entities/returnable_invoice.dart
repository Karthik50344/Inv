import 'package:equatable/equatable.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// A posted invoice offered in the "choose the invoice" step.
final class InvoiceChoice extends Equatable {
  /// Creates a choice.
  const InvoiceChoice({
    required this.kind,
    required this.id,
    required this.number,
    required this.partyName,
    required this.invoiceDate,
    required this.total,
  });

  /// Sales or purchase.
  final InvoiceKind kind;

  /// Invoice id.
  final String id;

  /// Invoice number.
  final String number;

  /// Customer or supplier name.
  final String partyName;

  /// Invoice date.
  final DateTime invoiceDate;

  /// Invoice total.
  final Money total;

  @override
  List<Object?> get props => [kind, id, number, partyName, invoiceDate, total];
}

/// One line of an invoice together with what has already been returned.
final class ReturnableLine extends Equatable {
  /// Creates a line.
  const ReturnableLine({
    required this.invoiceLineId,
    required this.lineNo,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.unitSymbol,
    required this.unitDecimalPlaces,
    required this.quantity,
    required this.net,
    required this.tax,
    required this.returnedQuantity,
    required this.returnedNet,
    required this.returnedTax,
    required this.restockedQuantity,
    required this.restockedCost,
    this.originalStockCost,
  });

  /// Id of the invoice line.
  final String invoiceLineId;

  /// 1-based position on the invoice.
  final int lineNo;

  /// The product.
  final String productId;

  /// Product name on the invoice.
  final String productName;

  /// Product SKU on the invoice.
  final String sku;

  /// Unit symbol on the invoice.
  final String unitSymbol;

  /// Decimal places of the unit on the invoice.
  final int unitDecimalPlaces;

  /// Quantity on the invoice.
  final Quantity quantity;

  /// Net value of the whole line.
  final Money net;

  /// Tax of the whole line.
  final Money tax;

  /// Quantity already returned by posted returns.
  final Quantity returnedQuantity;

  /// Net value already returned.
  final Money returnedNet;

  /// Tax already returned.
  final Money returnedTax;

  /// Sales: quantity already put back into stock.
  final Quantity restockedQuantity;

  /// Sales: value already put back into stock.
  final Money restockedCost;

  /// Sales: what the goods cost when they were sold (from the stock
  /// ledger); `null` when unknown or for purchases.
  final Money? originalStockCost;

  /// Quantity that can still be returned.
  Quantity get returnable => quantity - returnedQuantity;

  /// Net plus tax of the whole line.
  Money get total => net + tax;

  @override
  List<Object?> get props => [
    invoiceLineId,
    lineNo,
    productId,
    productName,
    sku,
    unitSymbol,
    unitDecimalPlaces,
    quantity,
    net,
    tax,
    returnedQuantity,
    returnedNet,
    returnedTax,
    restockedQuantity,
    restockedCost,
    originalStockCost,
  ];
}

/// A posted invoice with everything needed to plan and validate a return.
final class ReturnableInvoice extends Equatable {
  /// Creates the view.
  const ReturnableInvoice({
    required this.kind,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.partyName,
    required this.invoiceDate,
    required this.open,
    required this.lines,
    this.partyId,
  });

  /// Sales or purchase.
  final InvoiceKind kind;

  /// Invoice id.
  final String invoiceId;

  /// Invoice number.
  final String invoiceNumber;

  /// Customer or supplier id; `null` for a walk-in sale.
  final String? partyId;

  /// Customer or supplier name.
  final String partyName;

  /// Invoice date.
  final DateTime invoiceDate;

  /// The invoice with its payments and returns so far.
  final OpenInvoice open;

  /// Lines ordered by line number.
  final List<ReturnableLine> lines;

  /// Whether the sale had no customer.
  bool get isWalkIn => partyId == null;

  /// Whether anything is left to return.
  bool get hasReturnable => lines.any((l) => l.returnable.isPositive);

  /// Zero in the invoice's currency.
  Money get zero => open.total - open.total;

  /// The most cash that can be handed back for a return worth
  /// [returnTotal]: only money the party has paid beyond what they still
  /// owe after this return. A walk-in sale was paid at the counter, so its
  /// whole return value can be handed back.
  Money refundCapacity(Money returnTotal) {
    if (isWalkIn) {
      return returnTotal;
    }
    final owedAfter = open.receivable - returnTotal;
    final spare = open.cashHeld - owedAfter;
    if (!spare.isPositive) {
      return zero;
    }
    return spare > returnTotal ? returnTotal : spare;
  }

  @override
  List<Object?> get props => [
    kind,
    invoiceId,
    invoiceNumber,
    partyId,
    partyName,
    invoiceDate,
    open,
    lines,
  ];
}
