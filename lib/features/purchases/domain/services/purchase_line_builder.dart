import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/decimal_text.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/product_classification/domain/repositories/product_classification_repository.dart';
import 'package:inventrix/features/taxation/domain/entities/line_tax_snapshot.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/tax_line_service.dart';
import 'package:inventrix/shared/domain/value_objects/line_amounts.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_line.dart';
import 'package:inventrix/shared/domain/services/line_calculator.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Turns a [PurchaseLineInput] into a validated [PurchaseLine] with product,
/// unit and tax snapshots.
///
/// The same builder backs saving a draft and the live totals preview on the
/// form, so what the user sees is exactly what gets stored.
final class PurchaseLineBuilder {
  /// Creates the builder.
  const PurchaseLineBuilder({
    required ProductRepository products,
    required UnitRepository units,
    required TaxRateRepository taxRates,
    TaxLineService? taxLines,
    ProductClassificationRepository? classifications,
  }) : _products = products,
       _units = units,
       _taxRates = taxRates,
       _taxLines = taxLines,
       _classifications = classifications;

  final ProductRepository _products;
  final UnitRepository _units;
  final TaxRateRepository _taxRates;
  final TaxLineService? _taxLines;
  final ProductClassificationRepository? _classifications;

  /// Builds the line. Invalid input fails with a `ValidationFailure` whose
  /// `fieldErrors` use the keys `product`, `quantity`, `unitPrice` and
  /// `discount`.
  Future<Result<PurchaseLine>> build({
    required PurchaseLineInput input,
    required int lineNo,
    required String lineId,
    required CurrencyConfig currency,
    DateTime? date,
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
        '${product.name} is archived. Restore it before purchasing.',
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
      unitPrice = product.purchasePrice;
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

    if (errors.isNotEmpty ||
        quantity == null ||
        unitPrice == null ||
        discount == null) {
      return Result.failure(_validation(errors));
    }

    // The configurable tax engine is used when the product has a tax
    // category (or override) and a default tax profile exists; otherwise the
    // single tax rate path below applies unchanged.
    final taxLines = _taxLines;
    final taxed = taxLines == null
        ? const Result<TaxedLine?>.success(null)
        : await taxLines.calculate(
            productTaxCategoryId: product.taxCategoryId,
            productTaxOverrideId: product.taxOverrideId,
            type: TaxTransactionType.purchase,
            date: date ?? DateTime.now().toUtc(),
            unitPrice: unitPrice,
            quantity: quantity,
            priceIncludesTax: product.priceIncludesTax,
            discount: discount,
          );
    if (taxed.isFailure) {
      return Result.failure(taxed.failureOrNull!);
    }
    final engine = taxed.valueOrNull;

    final LineAmounts computed;
    var taxRateBp = 0;
    String? taxName;
    LineTaxSnapshot? taxSnapshot;
    if (engine != null) {
      computed = engine.amounts;
      taxRateBp = engine.taxRateBp;
      taxName = engine.taxName;
      taxSnapshot = engine.snapshot;
    } else {
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
      final amounts = LineCalculator.calculate(
        unitPrice: unitPrice,
        quantity: quantity,
        priceIncludesTax: product.priceIncludesTax,
        discount: discount,
        taxRateBp: taxRateBp,
      );
      final legacy = amounts.valueOrNull;
      if (legacy == null) {
        return Result.failure(amounts.failureOrNull!);
      }
      computed = legacy;
    }

    ClassificationSnapshot? classification;
    final classifications = _classifications;
    if (classifications != null) {
      final primary = await classifications.primaryFor(product.id);
      if (primary.isFailure) {
        return Result.failure(primary.failureOrNull!);
      }
      final p = primary.valueOrNull;
      if (p != null) {
        classification = ClassificationSnapshot(
          system: p.system.code,
          code: p.code,
          description: p.description,
        );
      }
    }
    return Result.success(
      PurchaseLine(
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
        taxSnapshot: taxSnapshot,
        classification: classification,
      ),
    );
  }

  Discount? _parseDiscount(
    PurchaseLineInput input,
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

  Result<PurchaseLine> _invalid(String field, String message) =>
      Result.failure(_validation({field: message}));

  ValidationFailure _validation(Map<String, String> errors) =>
      ValidationFailure(
        'Please correct the highlighted fields.',
        fieldErrors: Map.unmodifiable(errors),
      );
}
