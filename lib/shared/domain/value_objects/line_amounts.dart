import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// The computed amounts of one purchase line.
///
/// `total == net + tax` always. For a tax-exclusive price, [net] is
/// `gross - discount` and tax is added on top; for a tax-inclusive price the
/// discounted amount is the [total] and [net] is what remains after
/// removing the tax. [net] is also the inventory cost of the line.
final class LineAmounts extends Equatable {
  /// Creates the amounts.
  const LineAmounts({
    required this.gross,
    required this.discount,
    required this.net,
    required this.tax,
    required this.total,
  });

  /// Unit price x quantity, before discount (includes tax when the price is
  /// tax-inclusive).
  final Money gross;

  /// Discount taken off [gross].
  final Money discount;

  /// Taxable amount: the line value excluding tax. Used as inventory cost.
  final Money net;

  /// Tax amount.
  final Money tax;

  /// What the line costs including tax.
  final Money total;

  @override
  List<Object?> get props => [gross, discount, net, tax, total];
}
