import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Everything needed to validate a manual stock operation on one product.
final class StockOperationContext {
  /// Creates a context.
  const StockOperationContext({
    required this.product,
    required this.unit,
    required this.currency,
  });

  /// The product.
  final Product product;

  /// Its unit (defines quantity precision).
  final UnitOfMeasure unit;

  /// Active currency.
  final CurrencyConfig currency;
}

/// Loads and validates the inputs shared by opening stock and adjustments.
final class StockOperationSupport {
  /// Creates the support service.
  const StockOperationSupport({
    required ProductRepository products,
    required UnitRepository units,
    required SettingsRepository settings,
  }) : _products = products,
       _units = units,
       _settings = settings;

  final ProductRepository _products;
  final UnitRepository _units;
  final SettingsRepository _settings;

  /// Loads the product, unit and currency. Archived products cannot receive
  /// stock operations.
  Future<Result<StockOperationContext>> load(String productId) async {
    final productResult = await _products.getById(productId);
    final product = productResult.valueOrNull;
    if (product == null) {
      return Result.failure(productResult.failureOrNull!);
    }
    if (product.isArchived) {
      return const Result.failure(
        ValidationFailure(
          'This product is archived. Restore it before changing its stock.',
        ),
      );
    }
    final unitResult = await _units.getById(product.unitId);
    final unit = unitResult.valueOrNull;
    if (unit == null) {
      return Result.failure(unitResult.failureOrNull!);
    }
    final currencyResult = await _settings.getCurrencyConfig();
    final currency = currencyResult.valueOrNull;
    if (currency == null) {
      return Result.failure(currencyResult.failureOrNull!);
    }
    return Result.success(
      StockOperationContext(product: product, unit: unit, currency: currency),
    );
  }

  /// Parses a strictly positive quantity within the unit's precision.
  Quantity? parseQuantity(
    String text,
    UnitOfMeasure unit,
    FieldErrors errors, {
    String field = 'quantity',
  }) {
    final quantity = Quantity.tryParse(
      text.trim(),
      maxDecimalPlaces: unit.decimalPlaces,
    );
    if (quantity == null) {
      errors.add(
        field,
        unit.decimalPlaces == 0
            ? 'Enter a whole number.'
            : 'Enter a number with up to ${unit.decimalPlaces} decimal places.',
      );
      return null;
    }
    if (!quantity.isPositive) {
      errors.add(field, 'Quantity must be greater than zero.');
      return null;
    }
    return quantity;
  }

  /// Parses an optional non-negative unit cost; `null` when blank.
  Money? parseUnitCost(
    String text,
    CurrencyConfig currency,
    FieldErrors errors, {
    String field = 'unitCost',
  }) {
    if (text.trim().isEmpty) {
      return null;
    }
    final money = currency.parse(text);
    if (money == null) {
      errors.add(
        field,
        'Enter a number with up to ${currency.decimalPlaces} decimal places.',
      );
      return null;
    }
    if (money.isNegative) {
      errors.add(field, 'Cost must not be negative.');
      return null;
    }
    return money;
  }
}
