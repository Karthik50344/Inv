import 'package:equatable/equatable.dart';
import 'package:inventrix/features/returns/domain/entities/return_input.dart';
import 'package:inventrix/features/returns/domain/entities/returnable_invoice.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// One line of a return as planned from the user's input.
final class PlannedReturnLine extends Equatable {
  /// Creates a planned line.
  const PlannedReturnLine({
    required this.line,
    required this.quantity,
    required this.net,
    required this.tax,
    required this.restock,
    this.stockCost,
    this.note,
  });

  /// The invoice line.
  final ReturnableLine line;

  /// Quantity to return (positive, within the returnable quantity).
  final Quantity quantity;

  /// Net value of the returned goods.
  final Money net;

  /// Tax of the returned goods.
  final Money tax;

  /// Whether the goods go back into stock (sales) or leave stock
  /// (purchases: always `true`).
  final bool restock;

  /// Sales with [restock]: the value that re-enters stock, from the cost
  /// the goods left with. `null` when that cost is unknown or nothing is
  /// restocked.
  final Money? stockCost;

  /// Optional note.
  final String? note;

  /// Net plus tax.
  Money get total => net + tax;

  @override
  List<Object?> get props => [
    line,
    quantity,
    net,
    tax,
    restock,
    stockCost,
    note,
  ];
}

/// The outcome of planning a return: valid lines, per-line problems and
/// totals of the valid lines.
final class ReturnPlan extends Equatable {
  /// Creates a plan.
  const ReturnPlan({
    required this.lines,
    required this.lineErrors,
    required this.net,
    required this.tax,
  });

  /// Lines that will be returned, in invoice order.
  final List<PlannedReturnLine> lines;

  /// Problems by invoice line id.
  final Map<String, String> lineErrors;

  /// Net value of the planned lines.
  final Money net;

  /// Tax of the planned lines.
  final Money tax;

  /// Net plus tax.
  Money get total => net + tax;

  /// Whether the plan can be posted: something is returned and no line has
  /// a problem.
  bool get isValid => lines.isNotEmpty && lineErrors.isEmpty;

  @override
  List<Object?> get props => [lines, lineErrors, net, tax];
}

/// Turns the user's text input into amounts, one line at a time, with the
/// rules that keep returns exact:
///
/// - a quantity must be positive, fit the unit's precision and not exceed
///   what has not been returned yet;
/// - the value of a returned part is the same share of the invoice line's
///   net and of its tax, rounded once;
/// - the return that completes a line takes the exact remainder, and no
///   return can take more than what is left, so the returns of a line
///   never add up to more than the line;
/// - a sales return that restocks puts the goods back at the cost they
///   left with, by the same share and the same completion rule.
///
/// Pure and deterministic: the same code serves the form preview and the
/// transactional posting, so what the user sees is what is posted.
abstract final class ReturnPlanner {
  /// Plans [inputs] against [invoice].
  static ReturnPlan plan(
    ReturnableInvoice invoice,
    List<ReturnLineInput> inputs,
  ) {
    final byId = {for (final l in invoice.lines) l.invoiceLineId: l};
    final errors = <String, String>{};
    final seen = <String>{};
    final planned = <String, PlannedReturnLine>{};
    for (final input in inputs) {
      final text = input.quantity.trim();
      final line = byId[input.invoiceLineId];
      if (line == null) {
        errors[input.invoiceLineId] = 'This line is not on the invoice.';
        continue;
      }
      if (text.isEmpty) {
        continue;
      }
      if (!seen.add(line.invoiceLineId)) {
        errors[line.invoiceLineId] = 'This line was entered twice.';
        continue;
      }
      final quantity = Quantity.tryParse(
        text,
        maxDecimalPlaces: line.unitDecimalPlaces,
      );
      if (quantity == null || quantity.isNegative) {
        errors[line.invoiceLineId] = line.unitDecimalPlaces == 0
            ? 'Enter a whole number.'
            : 'Enter a number with at most ${line.unitDecimalPlaces} '
                  'decimal places.';
        continue;
      }
      if (quantity.isZero) {
        continue;
      }
      if (quantity > line.returnable) {
        errors[line.invoiceLineId] = line.returnable.isPositive
            ? 'Only ${line.returnable.toDecimalString()} '
                  '${line.unitSymbol} can still be returned.'
            : 'Everything on this line has already been returned.';
        continue;
      }
      planned[line.invoiceLineId] = _plan(invoice, line, quantity, input);
    }
    final lines = [
      for (final line in invoice.lines)
        if (planned[line.invoiceLineId] != null) planned[line.invoiceLineId]!,
    ];
    return ReturnPlan(
      lines: lines,
      lineErrors: errors,
      net: Money.sum(
        lines.map((l) => l.net),
        currencyCode: invoice.zero.currencyCode,
        decimalPlaces: invoice.zero.decimalPlaces,
      ),
      tax: Money.sum(
        lines.map((l) => l.tax),
        currencyCode: invoice.zero.currencyCode,
        decimalPlaces: invoice.zero.decimalPlaces,
      ),
    );
  }

  static PlannedReturnLine _plan(
    ReturnableInvoice invoice,
    ReturnableLine line,
    Quantity quantity,
    ReturnLineInput input,
  ) {
    final completes = line.returnedQuantity + quantity == line.quantity;
    final net = _share(
      whole: line.net,
      alreadyReturned: line.returnedNet,
      part: quantity,
      of: line.quantity,
      completes: completes,
    );
    final tax = _share(
      whole: line.tax,
      alreadyReturned: line.returnedTax,
      part: quantity,
      of: line.quantity,
      completes: completes,
    );
    final restock = invoice.kind == InvoiceKind.purchase || input.restock;
    Money? stockCost;
    if (invoice.kind == InvoiceKind.sales && restock) {
      final original = line.originalStockCost;
      if (original != null) {
        final left = _atLeastZero(original - line.restockedCost);
        final everythingBack =
            line.restockedQuantity + quantity == line.quantity;
        stockCost = everythingBack
            ? left
            : _min(original.prorate(quantity, line.quantity), left);
      }
    }
    final note = input.note.trim();
    return PlannedReturnLine(
      line: line,
      quantity: quantity,
      net: net,
      tax: tax,
      restock: restock,
      stockCost: stockCost,
      note: note.isEmpty ? null : note,
    );
  }

  /// The share `part / of` of [whole], never more than what has not been
  /// returned yet; the completing return takes the exact remainder.
  static Money _share({
    required Money whole,
    required Money alreadyReturned,
    required Quantity part,
    required Quantity of,
    required bool completes,
  }) {
    final left = _atLeastZero(whole - alreadyReturned);
    if (completes) {
      return left;
    }
    return _min(whole.prorate(part, of), left);
  }

  static Money _atLeastZero(Money value) =>
      value.isNegative ? value - value : value;

  static Money _min(Money a, Money b) => a <= b ? a : b;
}
