import 'package:equatable/equatable.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// What posted returns say about one invoice, in minor units.
final class InvoiceReturnTotals extends Equatable {
  /// Creates totals.
  const InvoiceReturnTotals({
    this.returnedMinor = 0,
    this.refundedMinor = 0,
    this.count = 0,
  });

  /// No returns.
  static const InvoiceReturnTotals none = InvoiceReturnTotals();

  /// Value of all returns (credit notes), including tax.
  final int returnedMinor;

  /// Cash handed back through returns (a part of [returnedMinor]).
  final int refundedMinor;

  /// Number of returns.
  final int count;

  @override
  List<Object?> get props => [returnedMinor, refundedMinor, count];
}

/// What posted returns say about one customer or supplier, in minor units.
final class PartyReturnTotals extends Equatable {
  /// Creates totals.
  const PartyReturnTotals({this.returnedMinor = 0, this.refundedMinor = 0});

  /// No returns.
  static const PartyReturnTotals none = PartyReturnTotals();

  /// Value of all returns, including tax.
  final int returnedMinor;

  /// Cash handed back through returns.
  final int refundedMinor;

  @override
  List<Object?> get props => [returnedMinor, refundedMinor];
}

/// Lets the payments feature see the effect of returns on invoices and
/// party balances without depending on the returns feature (which itself
/// depends on payments). Implemented by the returns data layer.
abstract interface class InvoiceReturnLookup {
  /// Return totals of each invoice in [invoiceIds]; invoices without
  /// returns are simply absent from the map.
  Future<Result<Map<String, InvoiceReturnTotals>>> totalsFor(
    InvoiceKind kind,
    Iterable<String> invoiceIds,
  );

  /// Return totals of one customer (sales returns) or supplier (purchase
  /// returns) in the given currency.
  Future<Result<PartyReturnTotals>> partyTotals(
    InvoiceKind kind,
    String partyId, {
    required String currencyCode,
    required int decimalPlaces,
  });
}

/// Lets the sales and purchase features ask whether an invoice has returns,
/// without depending on the returns feature. A returned invoice cannot be
/// voided: the return already reversed part of it.
abstract interface class InvoiceReturnGuard {
  /// Whether at least one return exists against the invoice.
  Future<Result<bool>> hasReturns(InvoiceKind kind, String invoiceId);
}
