import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/payments/domain/entities/invoice_settlement.dart';
import 'package:inventrix/features/payments/domain/entities/party_payment_totals.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_allocation.dart';
import 'package:inventrix/features/payments/domain/entities/payment_filter.dart';
import 'package:inventrix/features/payments/domain/entities/payment_reversal.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';

/// Persistence contract for payments, allocations and reversals.
///
/// Rows are append-only: there is no update or delete. Methods that write are
/// meant to be called inside a `TransactionRunner` action.
abstract interface class PaymentRepository {
  /// The payment recorded with [key], if any (for idempotent recording).
  Future<Result<Payment?>> findByIdempotencyKey(String key);

  /// Loads a payment with its allocations and reversal; `NotFoundFailure`
  /// if missing.
  Future<Result<Payment>> getById(String id);

  /// Payment history, newest first, with allocations and reversals.
  Future<Result<List<Payment>>> search(PaymentFilter filter);

  /// Refunds taken from [paymentId] that have not been reversed.
  Future<Result<List<Payment>>> activeRefundsOf(String paymentId);

  /// Inserts the payment and its allocations.
  Future<Result<void>> insert(Payment payment);

  /// Inserts further allocations for an existing payment.
  Future<Result<void>> insertAllocations(List<PaymentAllocation> allocations);

  /// Inserts a reversal; fails with `DuplicateEntryFailure` if the payment
  /// is already reversed.
  Future<Result<void>> insertReversal(PaymentReversal reversal);

  /// Settlement of each invoice in [invoiceIds], active payments only.
  Future<Result<Map<String, InvoiceSettlement>>> settlements(
    InvoiceKind kind,
    Iterable<String> invoiceIds,
  );

  /// Active payment and refund totals of one customer or supplier in the
  /// given currency.
  Future<Result<PartyPaymentTotals>> partyTotals(
    PartyType type,
    String partyId, {
    required String currencyCode,
    required int decimalPlaces,
  });
}
