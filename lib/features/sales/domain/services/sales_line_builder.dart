import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/decimal_text.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/domain/entities/sales_line.dart';
import 'package:inventrix/shared/domain/services/line_calculator.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Turns a [SalesLineInput] into a validated [SalesLine] with product,
/// unit and tax snapshots.
///
/// The same builder backs saving a draft and the live totals preview on the
/// form, so what the user sees is exactly what gets stored.
final class SalesLineBuilder {
  /// Creates the builder.
  const SalesLineBuilder({
    required ProductRepository products,
    required UnitRepository units,
    required TaxRateRepository taxRates,
  }) : _products = products,
       _units = units,
       _taxRates = taxRates;

  final ProductRepository _products;
  final UnitRepository _units;
  final TaxRateRepository _taxRates;

  /// Builds the line. Invalid input fails with a `ValidationFailure` whose
  /// `fieldErrors` use the keys `product`, `quantity`, `unitPrice` and
  /// `discount`.
  Future<Result<SalesLine>> build({
    required SalesLineInput input,
    required int lineNo,
    required String lineId,
    required CurrencyConfig currency,
  }) async {
    final productResult = await _products.getById(input.productId);
    final product = productResult.valueOrNull;
    if (product == null) {
      final failure = productResult.failureOrNull!;
      return failure is NotFoundFailure
          ? _invalid('product', 'This product no longer exists.')
          : Result.failure(failure);
    }
    if (product.isArchived) {
      return _invalid(
        'product',
        '${product.name} is archived. Restore it before selling it.',
      );
    }
    final unitResult = await _units.getById(product.unitId);
    final unit = unitResult.valueOrNull;
    if (unit == null) {
      return Result.failure(unitResult.failureOrNull!);
    }

    final errors = <String, String>{};
    final quantity = Quantity.tryParse(
      input.quantity.trim(),
      maxDecimalPlaces: unit.decimalPlaces,
    );
    if (quantity == null) {
      errors['quantity'] = unit.decimalPlaces == 0
          ? 'Enter a whole number.'
          : 'Enter a number with up to ${unit.decimalPlaces} decimal places.';
    } else if (!quantity.isPositive) {
      errors['quantity'] = 'Quantity must be greater than zero.';
    }

    Money? unitPrice;
    if (input.unitPrice.trim().isEmpty) {
      unitPrice = product.sellingPrice;
    } else {
      unitPrice = currency.parse(input.unitPrice);
      if (unitPrice == null) {
        errors['unitPrice'] =
            'Enter a number with up to ${currency.decimalPlaces} '
            'decimal places.';
      } else if (unitPrice.isNegative) {
        errors['unitPrice'] = 'Price must not be negative.';
        unitPrice = null;
      }
    }

    final discount = _parseDiscount(input, currency, errors);

    var taxRateBp = 0;
    String? taxName;
    final taxRateId = product.taxRateId;
    if (taxRateId != null) {
      final taxResult = await _taxRates.getById(taxRateId);
      final tax = taxResult.valueOrNull;
      if (tax == null) {
        return Result.failure(taxResult.failureOrNull!);
      }
      taxRateBp = tax.isExempt ? 0 : tax.rateBp;
      taxName = tax.name;
    }

    if (errors.isNotEmpty ||
        quantity == null ||
        unitPrice == null ||
        discount == null) {
      return Result.failure(_validation(errors));
    }

    final amounts = LineCalculator.calculate(
      unitPrice: unitPrice,
      quantity: quantity,
      priceIncludesTax: product.priceIncludesTax,
      discount: discount,
      taxRateBp: taxRateBp,
    );
    final computed = amounts.valueOrNull;
    if (computed == null) {
      return Result.failure(amounts.failureOrNull!);
    }
    return Result.success(
      SalesLine(
        id: lineId,
        lineNo: lineNo,
        productId: product.id,
        productName: product.name,
        sku: product.sku,
        unitSymbol: unit.symbol,
        unitDecimalPlaces: unit.decimalPlaces,
        quantity: quantity,
        unitPrice: unitPrice,
        priceIncludesTax: product.priceIncludesTax,
        discount: discount,
        taxRateBp: taxRateBp,
        taxName: taxName,
        amounts: computed,
      ),
    );
  }

  Discount? _parseDiscount(
    SalesLineInput input,
    CurrencyConfig currency,
    Map<String, String> errors,
  ) {
    switch (input.discountKind) {
      case DiscountKind.none:
        return const Discount.none();
      case DiscountKind.percent:
        final bp = parseScaledDecimal(input.discountValue, scale: 2);
        if (bp == null || bp < 0) {
          errors['discount'] =
              'Enter a percentage with up to 2 decimal places.';
          return null;
        }
        if (bp > 10000) {
          errors['discount'] = 'A discount cannot be more than 100%.';
          return null;
        }
        return Discount.percent(bp);
      case DiscountKind.amount:
        final amount = currency.parse(input.discountValue);
        if (amount == null || amount.isNegative) {
          errors['discount'] =
              'Enter an amount with up to ${currency.decimalPlaces} '
              'decimal places.';
          return null;
        }
        return Discount.amount(amount);
    }
  }

  Result<SalesLine> _invalid(String field, String message) =>
      Result.failure(_validation({field: message}));

  ValidationFailure _validation(Map<String, String> errors) =>
      ValidationFailure(
        'Please correct the highlighted fields.',
        fieldErrors: Map.unmodifiable(errors),
      );
}
