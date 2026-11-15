import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/services/expense_calculator.dart';

/// Re-checks a stored expense before it is posted. UI and earlier saves are
/// advisory: posting trusts only what it verifies itself.
abstract final class ExpenseIntegrity {
  /// Returns a description of the first problem found, or `null` if the
  /// expense is sound.
  static String? findProblem(Expense expense) {
    final amounts = expense.amounts;
    if (!amounts.total.isPositive) {
      return 'The amount must be greater than zero.';
    }
    if (amounts.net.isNegative || amounts.tax.isNegative) {
      return 'Net and tax amounts must not be negative.';
    }
    if (amounts.net + amounts.tax != amounts.total) {
      return 'The expense total does not match its net and tax amounts.';
    }
    if (expense.description.trim().isEmpty) {
      return 'The expense needs a description.';
    }
    if (expense.taxRateBp < 0) {
      return 'The tax rate is invalid.';
    }
    // Recompute from the entered amount; a mismatch means the stored
    // figures were altered or calculated differently.
    final entered = expense.amountIncludesTax && expense.taxRateBp > 0
        ? amounts.total
        : amounts.net;
    final expected = ExpenseCalculator.calculate(
      amount: entered,
      includesTax: expense.amountIncludesTax,
      taxRateBp: expense.taxRateBp,
    );
    if (expected != amounts) {
      return 'The expense amounts are inconsistent. Edit and save the '
          'draft again.';
    }
    return null;
  }
}
