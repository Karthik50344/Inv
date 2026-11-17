import 'package:equatable/equatable.dart';

/// Which stored amounts have **no currency of their own** and would silently
/// change meaning if the currency or its decimals changed.
///
/// Invoices, payments, returns and expenses keep a snapshot of their
/// currency, so their history stays correct. Product prices, opening
/// balances and stock costs are plain numbers in the active currency, and a
/// posted invoice can only be settled in the active currency; while any of
/// them exists, the currency is locked.
final class MoneyLock extends Equatable {
  /// Creates a lock report.
  const MoneyLock({
    this.pricedProducts = 0,
    this.openingBalances = 0,
    this.stockRecords = 0,
    this.postedInvoices = 0,
  });

  /// Nothing is stored that depends on the currency.
  static const MoneyLock none = MoneyLock();

  /// Products with a purchase or selling price.
  final int pricedProducts;

  /// Customers and suppliers with an opening balance.
  final int openingBalances;

  /// Stock movements and balances that carry a cost or value.
  final int stockRecords;

  /// Posted sales and purchase invoices with an amount (they could no
  /// longer be paid after a change).
  final int postedInvoices;

  /// Whether the currency can no longer be changed.
  bool get isLocked =>
      pricedProducts > 0 ||
      openingBalances > 0 ||
      stockRecords > 0 ||
      postedInvoices > 0;

  /// Why the currency is locked, in words for the owner; empty when free.
  String get reason {
    final parts = <String>[
      if (pricedProducts > 0)
        '$pricedProducts ${pricedProducts == 1 ? 'product has' : 'products have'} a price',
      if (openingBalances > 0)
        '$openingBalances ${openingBalances == 1 ? 'party has' : 'parties have'} an opening balance',
      if (stockRecords > 0) 'stock with a cost is recorded',
      if (postedInvoices > 0)
        '$postedInvoices ${postedInvoices == 1 ? 'invoice is' : 'invoices are'} posted',
    ];
    return parts.join(', ');
  }

  @override
  List<Object?> get props => [
    pricedProducts,
    openingBalances,
    stockRecords,
    postedInvoices,
  ];
}
