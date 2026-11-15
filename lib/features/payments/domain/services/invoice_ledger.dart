import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/payments/domain/entities/invoice_settlement.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_filter.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/sales/domain/entities/sales_filter.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/services/invoice_return_lookup.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Combines invoices (sales or purchases) with what active payments and
/// posted returns have settled against them. All payment arithmetic starts here, so the rest of
/// the feature never re-derives "outstanding".
final class InvoiceLedger {
  /// Creates a ledger.
  const InvoiceLedger({
    required SalesRepository sales,
    required PurchaseRepository purchases,
    required PaymentRepository payments,
    required InvoiceReturnLookup returns,
  }) : _sales = sales,
       _purchases = purchases,
       _payments = payments,
       _returns = returns;

  final SalesRepository _sales;
  final PurchaseRepository _purchases;
  final PaymentRepository _payments;
  final InvoiceReturnLookup _returns;

  /// Loads one invoice with its settlement; `NotFoundFailure` if missing.
  Future<Result<OpenInvoice>> get(InvoiceKind kind, String invoiceId) async {
    final settlementResult = await _payments.settlements(kind, [invoiceId]);
    final settlements = settlementResult.valueOrNull;
    if (settlements == null) {
      return Result.failure(settlementResult.failureOrNull!);
    }
    final settlement = settlements[invoiceId] ?? InvoiceSettlement.none;
    final returnsResult = await _returns.totalsFor(kind, [invoiceId]);
    final returnTotals = returnsResult.valueOrNull;
    if (returnTotals == null) {
      return Result.failure(returnsResult.failureOrNull!);
    }
    final returned = returnTotals[invoiceId] ?? InvoiceReturnTotals.none;
    switch (kind) {
      case InvoiceKind.sales:
        final result = await _sales.getById(invoiceId);
        final invoice = result.valueOrNull;
        if (invoice == null) {
          return Result.failure(result.failureOrNull!);
        }
        return Result.success(
          _build(
            kind: kind,
            id: invoice.id,
            partyId: invoice.customerId ?? '',
            partyName: invoice.customerName,
            status: invoice.status,
            number: invoice.number,
            date: invoice.invoiceDate,
            dueDate: invoice.dueDate,
            total: invoice.totals.total,
            settlement: settlement,
            returned: returned,
          ),
        );
      case InvoiceKind.purchase:
        final result = await _purchases.getById(invoiceId);
        final invoice = result.valueOrNull;
        if (invoice == null) {
          return Result.failure(result.failureOrNull!);
        }
        return Result.success(
          _build(
            kind: kind,
            id: invoice.id,
            partyId: invoice.supplierId,
            partyName: invoice.supplierName,
            status: invoice.status,
            number: invoice.number,
            date: invoice.invoiceDate,
            dueDate: invoice.dueDate,
            total: invoice.totals.total,
            settlement: settlement,
            returned: returned,
          ),
        );
    }
  }

  /// Posted invoices of one customer or supplier with their settlement,
  /// newest first.
  Future<Result<List<OpenInvoice>>> postedFor(
    PartyType type,
    String partyId,
  ) async {
    final kind = type.invoiceKind;
    final rows = <_Row>[];
    switch (type) {
      case PartyType.customer:
        final result = await _sales.search(
          SalesFilter(status: DocumentStatus.posted, customerId: partyId),
        );
        final list = result.valueOrNull;
        if (list == null) {
          return Result.failure(result.failureOrNull!);
        }
        rows.addAll(
          list.map(
            (s) => _Row(
              id: s.id,
              partyId: partyId,
              partyName: s.customerName,
              status: s.status,
              number: s.number,
              date: s.invoiceDate,
              dueDate: s.dueDate,
              total: s.total,
            ),
          ),
        );
      case PartyType.supplier:
        final result = await _purchases.search(
          PurchaseFilter(status: DocumentStatus.posted, supplierId: partyId),
        );
        final list = result.valueOrNull;
        if (list == null) {
          return Result.failure(result.failureOrNull!);
        }
        rows.addAll(
          list.map(
            (s) => _Row(
              id: s.id,
              partyId: partyId,
              partyName: s.supplierName,
              status: s.status,
              number: s.number,
              date: s.invoiceDate,
              dueDate: s.dueDate,
              total: s.total,
            ),
          ),
        );
    }
    final settlementResult = await _payments.settlements(kind, [
      for (final row in rows) row.id,
    ]);
    final settlements = settlementResult.valueOrNull;
    if (settlements == null) {
      return Result.failure(settlementResult.failureOrNull!);
    }
    final returnsResult = await _returns.totalsFor(kind, [
      for (final row in rows) row.id,
    ]);
    final returnTotals = returnsResult.valueOrNull;
    if (returnTotals == null) {
      return Result.failure(returnsResult.failureOrNull!);
    }
    return Result.success([
      for (final row in rows)
        _build(
          kind: kind,
          id: row.id,
          partyId: row.partyId,
          partyName: row.partyName,
          status: row.status,
          number: row.number,
          date: row.date,
          dueDate: row.dueDate,
          total: row.total,
          settlement: settlements[row.id] ?? InvoiceSettlement.none,
          returned: returnTotals[row.id] ?? InvoiceReturnTotals.none,
        ),
    ]);
  }

  static OpenInvoice _build({
    required InvoiceKind kind,
    required String id,
    required String partyId,
    required String partyName,
    required DocumentStatus status,
    required String? number,
    required DateTime date,
    required DateTime? dueDate,
    required Money total,
    required InvoiceSettlement settlement,
    required InvoiceReturnTotals returned,
  }) {
    Money money(int minor) => Money.fromMinor(
      minor,
      currencyCode: total.currencyCode,
      decimalPlaces: total.decimalPlaces,
    );
    return OpenInvoice(
      kind: kind,
      id: id,
      partyId: partyId,
      partyName: partyName,
      documentStatus: status,
      number: number,
      invoiceDate: date,
      dueDate: dueDate,
      total: total,
      netPaid: money(settlement.netPaidMinor),
      refunded: money(settlement.refundedMinor),
      returned: money(returned.returnedMinor),
      returnRefunded: money(returned.refundedMinor),
    );
  }
}

class _Row {
  const _Row({
    required this.id,
    required this.partyId,
    required this.partyName,
    required this.status,
    required this.number,
    required this.date,
    required this.dueDate,
    required this.total,
  });

  final String id;
  final String partyId;
  final String partyName;
  final DocumentStatus status;
  final String? number;
  final DateTime date;
  final DateTime? dueDate;
  final Money total;
}
