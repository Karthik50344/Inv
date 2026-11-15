import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/payments/domain/entities/invoice_settlement_view.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_filter.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/payments/domain/services/invoice_ledger.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// Reads settlement information for the payment screens.
final class GetOpenInvoices {
  /// Creates the use case.
  const GetOpenInvoices({
    required InvoiceLedger ledger,
    required PaymentRepository payments,
    required Clock clock,
  }) : _ledger = ledger,
       _payments = payments,
       _clock = clock;

  final InvoiceLedger _ledger;
  final PaymentRepository _payments;
  final Clock _clock;

  /// Posted invoices of a party that still have something outstanding,
  /// oldest first.
  Future<Result<List<OpenInvoice>>> forParty(
    PartyType type,
    String partyId,
  ) async {
    final result = await _ledger.postedFor(type, partyId);
    return result.map(
      (list) =>
          [
            for (final invoice in list)
              if (invoice.outstanding.isPositive) invoice,
          ]..sort((a, b) {
            final byDate = a.invoiceDate.compareTo(b.invoiceDate);
            return byDate != 0
                ? byDate
                : a.displayNumber.compareTo(b.displayNumber);
          }),
    );
  }

  /// One invoice with its derived payment status and the payments settling it.
  Future<Result<InvoiceSettlementView>> settlementOf(
    InvoiceKind kind,
    String invoiceId,
  ) async {
    final invoiceResult = await _ledger.get(kind, invoiceId);
    final invoice = invoiceResult.valueOrNull;
    if (invoice == null) {
      return Result.failure(invoiceResult.failureOrNull!);
    }
    final paymentsResult = await _payments.search(
      PaymentFilter(invoiceId: invoiceId, includeReversed: false),
    );
    final payments = paymentsResult.valueOrNull;
    if (payments == null) {
      return Result.failure(paymentsResult.failureOrNull!);
    }
    return Result.success(
      InvoiceSettlementView(
        invoice: invoice,
        status: invoice.statusAt(_clock.now()),
        payments: payments,
      ),
    );
  }
}
