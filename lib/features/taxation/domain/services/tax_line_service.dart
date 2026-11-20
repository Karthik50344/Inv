import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/taxation/domain/entities/line_tax_snapshot.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_repository.dart';
import 'package:inventrix/features/taxation/domain/services/product_tax_classifier.dart';
import 'package:inventrix/features/taxation/domain/services/tax_calculator.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/line_amounts.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// A line taxed by the engine: the amounts, the frozen snapshot and the two
/// legacy summary figures the invoice item columns still carry.
final class TaxedLine {
  /// Creates the outcome.
  const TaxedLine({
    required this.amounts,
    required this.snapshot,
    required this.taxRateBp,
    required this.taxName,
  });

  /// Gross, discount, net, tax and total of the line.
  final LineAmounts amounts;

  /// What gets frozen with the document.
  final LineTaxSnapshot snapshot;

  /// Sum of the percentage components (capped at 1000%), for the legacy
  /// `tax_rate_bp` column.
  final int taxRateBp;

  /// Component names joined with ` + ` (or the category name when there are
  /// none), for the legacy `tax_name` column.
  final String taxName;
}

/// Taxes one document line through the configurable engine.
///
/// Returns `null` (not a failure) when the line should use the legacy
/// single-rate path: the product has neither a tax category nor an override,
/// or no default tax profile exists yet.
final class TaxLineService {
  /// Creates the service.
  const TaxLineService({
    required TaxRepository repository,
    TaxCalculator calculator = const TaxCalculator(),
  }) : _repository = repository,
       _calculator = calculator;

  final TaxRepository _repository;
  final TaxCalculator _calculator;

  /// Calculates the tax of a line. The discount is resolved against the
  /// line gross exactly as `LineCalculator` does.
  Future<Result<TaxedLine?>> calculate({
    required String? productTaxCategoryId,
    required String? productTaxOverrideId,
    required TaxTransactionType type,
    required DateTime date,
    required Money unitPrice,
    required Quantity quantity,
    required bool priceIncludesTax,
    required Discount discount,
  }) async {
    if (productTaxCategoryId == null && productTaxOverrideId == null) {
      return const Result.success(null);
    }
    final loadedContext = await _repository.loadContext();
    final context = loadedContext.valueOrNull;
    if (context == null) {
      return loadedContext.isFailure
          ? Result.failure(loadedContext.failureOrNull!)
          : const Result.success(null);
    }
    final loadedConfig = await _repository.loadConfiguration();
    final configuration = loadedConfig.valueOrNull;
    if (configuration == null) {
      return Result.failure(loadedConfig.failureOrNull!);
    }

    final category = ProductTaxClassifier.resolve(
      configuration: configuration,
      taxProfileId: context.taxProfileId,
      productTaxCategoryId: productTaxCategoryId,
      productTaxOverrideId: productTaxOverrideId,
    );
    final effective = category.valueOrNull;
    if (effective == null) {
      return Result.failure(category.failureOrNull!);
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

    final calculated = _calculator.calculate(
      configuration,
      TaxCalculationInput(
        taxProfileId: context.taxProfileId,
        taxCategoryId: effective.categoryId,
        transactionType: type,
        transactionDate: date,
        pricingMode: priceIncludesTax
            ? PricingMode.inclusive
            : PricingMode.exclusive,
        sellerLocation: context.sellerLocation,
        placeOfSupply: context.sellerLocation,
        grossAmount: gross,
        quantity: quantity,
        discount: discountAmount,
        isSellerTaxRegistered: context.isSellerTaxRegistered,
      ),
    );
    final result = calculated.valueOrNull;
    if (result == null) {
      return Result.failure(calculated.failureOrNull!);
    }

    var rate = 0;
    final names = <String>[];
    for (final c in result.components) {
      rate += c.rateBasisPoints ?? 0;
      names.add(c.name);
    }
    final categoryName =
        configuration.category(effective.categoryId)?.name ?? '';
    return Result.success(
      TaxedLine(
        amounts: LineAmounts(
          gross: gross,
          discount: discountAmount,
          net: result.taxableAmount,
          tax: result.taxCharged,
          total: result.totalAmount,
        ),
        snapshot: LineTaxSnapshot.fromResult(result),
        taxRateBp: rate > 100000 ? 100000 : rate,
        taxName: names.isEmpty ? categoryName : names.join(' + '),
      ),
    );
  }
}
