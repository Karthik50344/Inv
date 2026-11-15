import 'package:inventrix/features/expenses/domain/entities/expense_amounts.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Net, tax and total of an expense. Rounds half away from zero, at most
/// once per figure, with no floating point; the same rules as invoice lines.
///
/// ```text
/// tax-exclusive:  net = amount,  tax = net x rate,      total = net + tax
/// tax-inclusive:  total = amount, net = total / (1 + rate), tax = total - net
/// ```
abstract final class ExpenseCalculator {
  /// Computes the amounts for an entered [amount].
  ///
  /// [taxRateBp] is in basis points (1% = 100); 0 means no tax. Throws
  /// [ArgumentError] for a negative amount or rate: callers validate user
  /// input first.
  static ExpenseAmounts calculate({
    required Money amount,
    required bool includesTax,
    required int taxRateBp,
  }) {
    if (amount.isNegative) {
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    }
    if (taxRateBp < 0) {
      throw ArgumentError.value(taxRateBp, 'taxRateBp', 'must not be negative');
    }
    if (taxRateBp == 0) {
      return ExpenseAmounts(net: amount, tax: amount - amount, total: amount);
    }
    if (includesTax) {
      final net = amount.netOfGross(taxRateBp);
      return ExpenseAmounts(net: net, tax: amount - net, total: amount);
    }
    final tax = amount.applyBasisPoints(taxRateBp);
    return ExpenseAmounts(net: amount, tax: tax, total: amount + tax);
  }
}
