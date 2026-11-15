import 'package:equatable/equatable.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Invoice totals: the sum of the line amounts (no invoice-level rounding,
/// so lines always add up to the totals exactly).
final class SalesTotals extends Equatable {
  /// Creates totals.
  const SalesTotals({
    required this.gross,
    required this.discount,
    required this.net,
    required this.tax,
    required this.total,
  });

  /// Sums [lines]; [zero] supplies the currency.
  factory SalesTotals.fromLines(
    Iterable<SalesLine> lines, {
    required Money zero,
  }) {
    var gross = zero;
    var discount = zero;
    var net = zero;
    var tax = zero;
    var total = zero;
    for (final line in lines) {
      gross += line.gross;
      discount += line.discountAmount;
      net += line.net;
      tax += line.tax;
      total += line.total;
    }
    return SalesTotals(
      gross: gross,
      discount: discount,
      net: net,
      tax: tax,
      total: total,
    );
  }

  /// Sum of line values before discount.
  final Money gross;

  /// Sum of line discounts.
  final Money discount;

  /// Sum of taxable amounts (value excluding tax).
  final Money net;

  /// Sum of tax.
  final Money tax;

  /// Amount receivable to the customer.
  final Money total;

  @override
  List<Object?> get props => [gross, discount, net, tax, total];
}
