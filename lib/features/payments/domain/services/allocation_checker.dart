import 'package:equatable/equatable.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/features/payments/domain/services/invoice_ledger.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// A validated allocation: the invoice as it stands and the amount to apply.
final class ResolvedAllocation extends Equatable {
  /// Creates a resolved allocation.
  const ResolvedAllocation({required this.invoice, required this.amount});

  /// The invoice being settled.
  final OpenInvoice invoice;

  /// Positive amount to apply.
  final Money amount;

  @override
  List<Object?> get props => [invoice, amount];
}

/// Validates requested allocations against the current state of the
/// invoices. Throws a [FailureException] (so the surrounding transaction
/// rolls back) as soon as a rule is broken; it never returns a partial list.
final class AllocationChecker {
  /// Creates a checker.
  const AllocationChecker(this._ledger);

  final InvoiceLedger _ledger;

  /// Rules, per request:
  /// - the amount is positive and in the same currency as [limit];
  /// - an invoice is allocated at most once per payment;
  /// - the invoice exists, is posted, belongs to the party and is in the
  ///   same currency;
  /// - the amount does not exceed what is outstanding (no over-allocation);
  /// and overall the allocations do not add up to more than [limit].
  Future<List<ResolvedAllocation>> resolve({
    required PartyType partyType,
    required String partyId,
    required List<AllocationRequest> requests,
    required Money limit,
  }) async {
    final seen = <String>{};
    final resolved = <ResolvedAllocation>[];
    var total = limit - limit;
    for (final request in requests) {
      if (!seen.add(request.invoiceId)) {
        throw const FailureException(
          ValidationFailure('An invoice can only be allocated once.'),
        );
      }
      final amount = request.amount;
      if (!amount.isPositive) {
        throw const FailureException(
          ValidationFailure('Each allocation must be greater than zero.'),
        );
      }
      if (amount.currencyCode != limit.currencyCode ||
          amount.decimalPlaces != limit.decimalPlaces) {
        throw const FailureException(
          ValidationFailure('Allocation currency does not match the payment.'),
        );
      }
      final result = await _ledger.get(partyType.invoiceKind, request.invoiceId);
      final invoice = result.valueOrNull;
      if (invoice == null) {
        throw FailureException(result.failureOrNull!);
      }
      final label = invoice.displayNumber;
      if (invoice.documentStatus != DocumentStatus.posted) {
        throw FailureException(
          ValidationFailure('$label is not posted, so it cannot be paid.'),
        );
      }
      if (invoice.partyId != partyId) {
        throw FailureException(
          ValidationFailure(
            '$label belongs to a different '
            '${partyType.label.toLowerCase()}.',
          ),
        );
      }
      if (invoice.total.currencyCode != amount.currencyCode ||
          invoice.total.decimalPlaces != amount.decimalPlaces) {
        throw FailureException(
          ValidationFailure(
            '$label is in ${invoice.total.currencyCode}; a payment in '
            '${amount.currencyCode} cannot settle it.',
          ),
        );
      }
      if (amount > invoice.outstanding) {
        throw FailureException(
          ValidationFailure(
            'The amount for $label is more than the outstanding '
            '${invoice.outstanding.toPlainString()}.',
          ),
        );
      }
      total += amount;
      resolved.add(ResolvedAllocation(invoice: invoice, amount: amount));
    }
    if (total > limit) {
      throw FailureException(
        ValidationFailure(
          'The allocations add up to ${total.toPlainString()}, which is more '
          'than the ${limit.toPlainString()} available.',
        ),
      );
    }
    return resolved;
  }
}
