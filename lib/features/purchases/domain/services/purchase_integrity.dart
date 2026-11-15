import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_totals.dart';
import 'package:inventrix/shared/domain/services/line_calculator.dart';

/// Re-checks a stored invoice before it is posted. Never trusts what the UI
/// or an earlier save produced: every figure is recomputed from the line
/// inputs.
abstract final class PurchaseIntegrity {
  /// Returns a user-facing problem description, or `null` when the invoice
  /// is internally consistent and may be posted.
  static String? findProblem(PurchaseInvoice invoice) {
    if (invoice.lines.isEmpty) {
      return 'The purchase has no lines.';
    }
    for (final line in invoice.lines) {
      if (!line.quantity.isPositive) {
        return 'Line ${line.lineNo} (${line.productName}) has no quantity.';
      }
      final recomputed = LineCalculator.calculate(
        unitPrice: line.unitPrice,
        quantity: line.quantity,
        priceIncludesTax: line.priceIncludesTax,
        discount: line.discount,
        taxRateBp: line.taxRateBp,
      ).valueOrNull;
      if (recomputed == null || recomputed != line.amounts) {
        return 'Line ${line.lineNo} (${line.productName}) does not add up. '
            'Open the draft and save it again.';
      }
    }
    final totals = PurchaseTotals.fromLines(
      invoice.lines,
      zero: invoice.totals.total - invoice.totals.total,
    );
    if (totals != invoice.totals) {
      return 'The invoice totals do not match its lines. '
          'Open the draft and save it again.';
    }
    return null;
  }
}
