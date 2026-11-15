import 'package:inventrix/features/payments/domain/entities/open_invoice.dart';
import 'package:inventrix/features/payments/domain/entities/payment_inputs.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Suggests how to spread a payment over open invoices.
abstract final class AllocationPlanner {
  /// Settles the oldest invoices first (by invoice date, then number) until
  /// [amount] is used up. Invoices without anything outstanding are skipped.
  /// Whatever cannot be allocated is simply left over as credit.
  static List<AllocationRequest> oldestFirst(
    Iterable<OpenInvoice> invoices,
    Money amount,
  ) {
    final ordered = invoices.where((i) => i.outstanding.isPositive).toList()
      ..sort((a, b) {
        final byDate = a.invoiceDate.compareTo(b.invoiceDate);
        return byDate != 0
            ? byDate
            : a.displayNumber.compareTo(b.displayNumber);
      });
    final result = <AllocationRequest>[];
    var remaining = amount;
    for (final invoice in ordered) {
      if (!remaining.isPositive) {
        break;
      }
      final outstanding = invoice.outstanding;
      final take = outstanding < remaining ? outstanding : remaining;
      result.add(AllocationRequest(invoiceId: invoice.id, amount: take));
      remaining -= take;
    }
    return result;
  }
}
