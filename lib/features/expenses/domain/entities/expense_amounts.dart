import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// The money figures of one expense. `total == net + tax` always.
///
/// For an amount entered tax-exclusive, [net] is the entered amount and tax
/// is added on top; for a tax-inclusive amount, [total] is the entered
/// amount and [net] is what remains after removing the tax.
final class ExpenseAmounts extends Equatable {
  /// Creates the amounts.
  const ExpenseAmounts({
    required this.net,
    required this.tax,
    required this.total,
  });

  /// The expense excluding tax.
  final Money net;

  /// Tax amount (zero when no tax applies).
  final Money tax;

  /// What was actually paid, including tax.
  final Money total;

  @override
  List<Object?> get props => [net, tax, total];
}
