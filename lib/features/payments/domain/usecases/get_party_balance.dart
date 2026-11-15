import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/payments/domain/entities/party_balance.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/services/party_directory.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/services/invoice_return_lookup.dart';

/// Computes what one customer owes or one supplier is owed, and lists every
/// party with an open balance.
///
/// `balance = opening + posted invoices - returns - active payments
/// + active refunds + cash handed back through returns`, in the current
/// currency. Nothing is stored: the figure is recomputed from
/// invoices and payments each time, so reversals recalculate it for free.
final class GetPartyBalance {
  /// Creates the use case.
  const GetPartyBalance({
    required PartyDirectory parties,
    required SalesRepository sales,
    required PurchaseRepository purchases,
    required PaymentRepository payments,
    required InvoiceReturnLookup returns,
    required SettingsRepository settings,
  }) : _parties = parties,
       _sales = sales,
       _purchases = purchases,
       _payments = payments,
       _returns = returns,
       _settings = settings;

  final PartyDirectory _parties;
  final SalesRepository _sales;
  final PurchaseRepository _purchases;
  final PaymentRepository _payments;
  final InvoiceReturnLookup _returns;
  final SettingsRepository _settings;

  /// The balance of one party.
  Future<Result<PartyBalance>> call(PartyType type, String partyId) async {
    final partyResult = await _parties.get(type, partyId);
    final party = partyResult.valueOrNull;
    if (party == null) {
      return Result.failure(partyResult.failureOrNull!);
    }
    return _balanceOf(party);
  }

  /// Parties whose balance is not zero, largest first. Archived parties are
  /// included because money can still be owed to or by them.
  Future<Result<List<PartyBalance>>> outstanding(PartyType type) async {
    final listResult = await _parties.all(type);
    final parties = listResult.valueOrNull;
    if (parties == null) {
      return Result.failure(listResult.failureOrNull!);
    }
    final balances = <PartyBalance>[];
    for (final party in parties) {
      final result = await _balanceOf(party);
      final balance = result.valueOrNull;
      if (balance == null) {
        return Result.failure(result.failureOrNull!);
      }
      if (!balance.isSettled) {
        balances.add(balance);
      }
    }
    balances.sort((a, b) => b.balance.compareTo(a.balance));
    return Result.success(balances);
  }

  Future<Result<PartyBalance>> _balanceOf(Party party) async {
    final currencyResult = await _settings.getCurrencyConfig();
    final currency = currencyResult.valueOrNull;
    if (currency == null) {
      return Result.failure(currencyResult.failureOrNull!);
    }
    final invoicedResult = party.type == PartyType.customer
        ? await _sales.postedTotalForCustomer(party.id)
        : await _purchases.postedTotalForSupplier(party.id);
    final invoiced = invoicedResult.valueOrNull;
    if (invoiced == null) {
      return Result.failure(invoicedResult.failureOrNull!);
    }
    final totalsResult = await _payments.partyTotals(
      party.type,
      party.id,
      currencyCode: currency.currencyCode,
      decimalPlaces: currency.decimalPlaces,
    );
    final totals = totalsResult.valueOrNull;
    if (totals == null) {
      return Result.failure(totalsResult.failureOrNull!);
    }
    final returnsResult = await _returns.partyTotals(
      party.type.invoiceKind,
      party.id,
      currencyCode: currency.currencyCode,
      decimalPlaces: currency.decimalPlaces,
    );
    final returnTotals = returnsResult.valueOrNull;
    if (returnTotals == null) {
      return Result.failure(returnsResult.failureOrNull!);
    }
    return Result.success(
      PartyBalance(
        partyType: party.type,
        partyId: party.id,
        partyName: party.name,
        opening: party.openingBalance,
        invoiced: invoiced,
        payments: currency.fromMinor(totals.paymentsMinor),
        refunds: currency.fromMinor(totals.refundsMinor),
        returns: currency.fromMinor(returnTotals.returnedMinor),
        returnRefunds: currency.fromMinor(returnTotals.refundedMinor),
      ),
    );
  }
}
