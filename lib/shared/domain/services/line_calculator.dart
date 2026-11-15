import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/shared/domain/value_objects/line_amounts.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Line arithmetic shared by purchase and sales documents. Every step rounds half away from zero and
/// at most once per figure; no floating point is involved.
///
/// ```text
/// gross    = unit price x quantity
/// discount = none | gross x percent | fixed amount (<= gross)
/// after    = gross - discount
/// tax-exclusive price:  net = after,        tax = net x rate,   total = net + tax
/// tax-inclusive price:  total = after,      net = total / (1 + rate),  tax = total - net
/// ```
///
/// `net` (the value excluding tax) is the inventory cost of the line.
abstract final class LineCalculator {
  /// Computes the amounts of a line.
  ///
  /// Fails with a `ValidationFailure` (field `discount`) when a fixed
  /// discount exceeds the line value. Throws [ArgumentError] for a
  /// non-positive [quantity], a negative [unitPrice] or a negative
  /// [taxRateBp]: callers validate user input before calling.
  static Result<LineAmounts> calculate({
    required Money unitPrice,
    required Quantity quantity,
    required bool priceIncludesTax,
    required Discount discount,
    required int taxRateBp,
  }) {
    if (!quantity.isPositive) {
      throw ArgumentError.value(quantity, 'quantity', 'must be positive');
    }
    if (unitPrice.isNegative) {
      throw ArgumentError.value(unitPrice, 'unitPrice', 'must not be negative');
    }
    if (taxRateBp < 0) {
      throw ArgumentError.value(taxRateBp, 'taxRateBp', 'must not be negative');
    }
    final gross = unitPrice.multiplyByQuantity(quantity);
    final discountAmount = discount.appliedTo(gross);
    if (discountAmount > gross) {
      return const Result.failure(
        ValidationFailure(
          'The discount cannot be more than the line amount.',
          fieldErrors: {
            'discount': 'The discount cannot be more than the line amount.',
          },
        ),
      );
    }
    final afterDiscount = gross - discountAmount;
    if (priceIncludesTax) {
      final net = afterDiscount.netOfGross(taxRateBp);
      return Result.success(
        LineAmounts(
          gross: gross,
          discount: discountAmount,
          net: net,
          tax: afterDiscount - net,
          total: afterDiscount,
        ),
      );
    }
    final tax = afterDiscount.applyBasisPoints(taxRateBp);
    return Result.success(
      LineAmounts(
        gross: gross,
        discount: discountAmount,
        net: afterDiscount,
        tax: tax,
        total: afterDiscount + tax,
      ),
    );
  }
}
