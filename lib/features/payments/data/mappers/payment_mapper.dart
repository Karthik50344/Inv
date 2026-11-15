import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_allocation.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/entities/payment_reversal.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Builds a [Payment] from its row, allocation rows and reversal row.
Payment paymentFromRows(
  PaymentRow row,
  List<PaymentAllocationRow> allocations,
  PaymentReversalRow? reversal,
) {
  Money money(int minor) => Money.fromMinor(
    minor,
    currencyCode: row.currencyCode,
    decimalPlaces: row.decimalPlaces,
  );
  final type = PartyType.fromDbName(row.partyType);
  return Payment(
    id: row.id,
    number: row.number,
    kind: PaymentKind.fromDbName(row.kind),
    partyType: type,
    partyId: (type == PartyType.customer ? row.customerId : row.supplierId)!,
    partyName: row.partyName,
    methodId: row.methodId,
    methodName: row.methodName,
    paymentDate: fromEpochMs(row.paymentDate),
    amount: money(row.amountMinor),
    idempotencyKey: row.idempotencyKey,
    createdAt: fromEpochMs(row.createdAt),
    reference: row.reference,
    notes: row.notes,
    refundOfPaymentId: row.refundOfPaymentId,
    allocations: [
      for (final a in allocations)
        PaymentAllocation(
          id: a.id,
          paymentId: a.paymentId,
          invoiceKind: a.salesInvoiceId != null
              ? InvoiceKind.sales
              : InvoiceKind.purchase,
          invoiceId: (a.salesInvoiceId ?? a.purchaseInvoiceId)!,
          invoiceNumber: a.invoiceNumber,
          amount: money(a.amountMinor),
          createdAt: fromEpochMs(a.createdAt),
        ),
    ],
    reversal: reversal == null
        ? null
        : PaymentReversal(
            id: reversal.id,
            paymentId: reversal.paymentId,
            reason: reversal.reason,
            reversedAt: fromEpochMs(reversal.reversedAt),
          ),
  );
}

/// Insert companion for a payment header.
PaymentsCompanion paymentToCompanion(Payment p) => PaymentsCompanion.insert(
  id: p.id,
  number: p.number,
  kind: p.kind.dbName,
  partyType: p.partyType.dbName,
  customerId: Value(p.partyType == PartyType.customer ? p.partyId : null),
  supplierId: Value(p.partyType == PartyType.supplier ? p.partyId : null),
  partyName: p.partyName,
  methodId: p.methodId,
  methodName: p.methodName,
  paymentDate: toEpochMs(p.paymentDate),
  amountMinor: p.amount.minorUnits,
  currencyCode: p.amount.currencyCode,
  decimalPlaces: p.amount.decimalPlaces,
  reference: Value(p.reference),
  notes: Value(p.notes),
  refundOfPaymentId: Value(p.refundOfPaymentId),
  idempotencyKey: p.idempotencyKey,
  createdAt: toEpochMs(p.createdAt),
);

/// Insert companion for one allocation.
PaymentAllocationsCompanion allocationToCompanion(PaymentAllocation a) =>
    PaymentAllocationsCompanion.insert(
      id: a.id,
      paymentId: a.paymentId,
      salesInvoiceId: Value(
        a.invoiceKind == InvoiceKind.sales ? a.invoiceId : null,
      ),
      purchaseInvoiceId: Value(
        a.invoiceKind == InvoiceKind.purchase ? a.invoiceId : null,
      ),
      invoiceNumber: a.invoiceNumber,
      amountMinor: a.amount.minorUnits,
      createdAt: toEpochMs(a.createdAt),
    );

/// Insert companion for a reversal.
PaymentReversalsCompanion reversalToCompanion(PaymentReversal r) =>
    PaymentReversalsCompanion.insert(
      id: r.id,
      paymentId: r.paymentId,
      reason: r.reason,
      reversedAt: toEpochMs(r.reversedAt),
    );

/// Converts a payment-method row.
PaymentMethod methodFromRow(PaymentMethodRow row) => PaymentMethod(
  id: row.id,
  name: row.name,
  createdAt: fromEpochMs(row.createdAt),
  archivedAt: fromEpochMsOrNull(row.archivedAt),
);

/// Companion for a payment method (insert or replace).
PaymentMethodsCompanion methodToCompanion(PaymentMethod m) =>
    PaymentMethodsCompanion(
      id: Value(m.id),
      name: Value(m.name),
      createdAt: Value(toEpochMs(m.createdAt)),
      archivedAt: Value(toEpochMsOrNull(m.archivedAt)),
    );
