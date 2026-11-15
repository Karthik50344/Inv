import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/validators/field_errors.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/categories/domain/repositories/category_repository.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/entities/product_fields.dart';
import 'package:inventrix/features/products/domain/repositories/product_repository.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

final RegExp _skuPattern = RegExp(r'^[A-Z0-9][A-Z0-9._/\-]{0,39}$');
final RegExp _barcodePattern = RegExp(r'^[A-Za-z0-9\-]{4,64}$');

/// Validates a [ProductDraft] against format rules, referenced master data
/// and uniqueness, and converts it into typed [ProductFields].
final class ProductValidator {
  /// Creates the validator.
  const ProductValidator({
    required ProductRepository products,
    required CategoryRepository categories,
    required UnitRepository units,
    required TaxRateRepository taxRates,
    required SettingsRepository settings,
  }) : _products = products,
       _categories = categories,
       _units = units,
       _taxRates = taxRates,
       _settings = settings;

  final ProductRepository _products;
  final CategoryRepository _categories;
  final UnitRepository _units;
  final TaxRateRepository _taxRates;
  final SettingsRepository _settings;

  /// Validates [draft]. When [existing] is given, its own SKU/barcode and
  /// already-archived references are allowed. A blank SKU is accepted only
  /// when [allowBlankSku] is true (it then comes back as `null`).
  Future<Result<ProductFields>> validate(
    ProductDraft draft, {
    Product? existing,
    bool allowBlankSku = false,
  }) async {
    final errors = FieldErrors()
      ..add(
        'name',
        Validators.requiredText(draft.name, label: 'Name', maxLength: 120),
      )
      ..add(
        'description',
        Validators.optionalText(
          draft.description,
          label: 'Description',
          maxLength: 1000,
        ),
      );

    final sku = _validateSku(draft.sku, allowBlankSku, errors);
    final barcode = _validateBarcode(draft.barcode, errors);

    final currencyResult = await _settings.getCurrencyConfig();
    final currency = currencyResult.valueOrNull;
    if (currency == null) {
      return Result.failure(currencyResult.failureOrNull!);
    }

    final unit = await _resolveUnit(draft.unitId, existing, errors);
    if (unit.failure != null) {
      return Result.failure(unit.failure!);
    }
    final categoryFailure = await _checkCategory(
      draft.categoryId,
      existing,
      errors,
    );
    if (categoryFailure != null) {
      return Result.failure(categoryFailure);
    }
    final taxFailure = await _checkTaxRate(draft.taxRateId, existing, errors);
    if (taxFailure != null) {
      return Result.failure(taxFailure);
    }

    final purchase = _price(
      draft.purchasePrice,
      'purchasePrice',
      'Purchase price',
      currency,
      errors,
    );
    final selling = _price(
      draft.sellingPrice,
      'sellingPrice',
      'Selling price',
      currency,
      errors,
    );

    Quantity? reorder;
    final unitPlaces = unit.decimalPlaces;
    if (unitPlaces != null) {
      reorder = _reorderLevel(draft.reorderLevel, unitPlaces, errors);
    }

    final uniqueness = await _checkUniqueness(sku, barcode, existing, errors);
    if (uniqueness != null) {
      return Result.failure(uniqueness);
    }
    if (!errors.isEmpty) {
      return Result.failure(errors.toFailure());
    }

    return Result.success(
      ProductFields(
        sku: sku,
        barcode: barcode,
        name: draft.name.trim(),
        description: blankToNull(draft.description),
        categoryId: draft.categoryId,
        unitId: draft.unitId,
        purchasePrice: purchase!,
        sellingPrice: selling!,
        priceIncludesTax: draft.priceIncludesTax,
        taxRateId: draft.taxRateId,
        reorderLevel: reorder!,
        imagePath: draft.imagePath,
      ),
    );
  }

  String? _validateSku(String raw, bool allowBlank, FieldErrors errors) {
    final sku = raw.trim().toUpperCase();
    if (sku.isEmpty) {
      if (!allowBlank) {
        errors.add('sku', 'SKU is required.');
      }
      return null;
    }
    if (!_skuPattern.hasMatch(sku)) {
      errors.add(
        'sku',
        'SKU may contain letters, numbers and . _ / - (max 40 characters).',
      );
      return null;
    }
    return sku;
  }

  String? _validateBarcode(String raw, FieldErrors errors) {
    final barcode = blankToNull(raw);
    if (barcode == null) {
      return null;
    }
    if (!_barcodePattern.hasMatch(barcode)) {
      errors.add('barcode', 'Barcode must be 4-64 letters, numbers or dashes.');
      return null;
    }
    return barcode;
  }

  Future<({int? decimalPlaces, Failure? failure})> _resolveUnit(
    String unitId,
    Product? existing,
    FieldErrors errors,
  ) async {
    if (unitId.isEmpty) {
      errors.add('unitId', 'Select a unit.');
      return (decimalPlaces: null, failure: null);
    }
    final result = await _units.getById(unitId);
    final unit = result.valueOrNull;
    if (unit == null) {
      final failure = result.failureOrNull!;
      if (failure is NotFoundFailure) {
        errors.add('unitId', 'The selected unit no longer exists.');
        return (decimalPlaces: null, failure: null);
      }
      return (decimalPlaces: null, failure: failure);
    }
    if (unit.isArchived && existing?.unitId != unitId) {
      errors.add('unitId', 'The selected unit is archived.');
    }
    return (decimalPlaces: unit.decimalPlaces, failure: null);
  }

  Future<Failure?> _checkCategory(
    String? categoryId,
    Product? existing,
    FieldErrors errors,
  ) async {
    if (categoryId == null) {
      return null;
    }
    final result = await _categories.getById(categoryId);
    final category = result.valueOrNull;
    if (category == null) {
      final failure = result.failureOrNull!;
      if (failure is NotFoundFailure) {
        errors.add('categoryId', 'The selected category no longer exists.');
        return null;
      }
      return failure;
    }
    if (category.isArchived && existing?.categoryId != categoryId) {
      errors.add('categoryId', 'The selected category is archived.');
    }
    return null;
  }

  Future<Failure?> _checkTaxRate(
    String? taxRateId,
    Product? existing,
    FieldErrors errors,
  ) async {
    if (taxRateId == null) {
      return null;
    }
    final result = await _taxRates.getById(taxRateId);
    final taxRate = result.valueOrNull;
    if (taxRate == null) {
      final failure = result.failureOrNull!;
      if (failure is NotFoundFailure) {
        errors.add('taxRateId', 'The selected tax rate no longer exists.');
        return null;
      }
      return failure;
    }
    if (taxRate.isArchived && existing?.taxRateId != taxRateId) {
      errors.add('taxRateId', 'The selected tax rate is archived.');
    }
    return null;
  }

  Money? _price(
    String text,
    String field,
    String label,
    CurrencyConfig currency,
    FieldErrors errors,
  ) {
    if (text.trim().isEmpty) {
      return currency.zero();
    }
    final money = currency.parse(text);
    if (money == null) {
      errors.add(
        field,
        '$label must be a number with up to ${currency.decimalPlaces} '
        'decimal places.',
      );
      return null;
    }
    if (money.isNegative) {
      errors.add(field, '$label must not be negative.');
      return null;
    }
    return money;
  }

  Quantity? _reorderLevel(String text, int unitPlaces, FieldErrors errors) {
    final source = text.trim().isEmpty ? '0' : text;
    final quantity = Quantity.tryParse(source, maxDecimalPlaces: unitPlaces);
    if (quantity == null) {
      errors.add(
        'reorderLevel',
        unitPlaces == 0
            ? 'Reorder level must be a whole number.'
            : 'Reorder level must be a number with up to $unitPlaces '
                  'decimal places.',
      );
      return null;
    }
    if (quantity.isNegative) {
      errors.add('reorderLevel', 'Reorder level must not be negative.');
      return null;
    }
    return quantity;
  }

  Future<Failure?> _checkUniqueness(
    String? sku,
    String? barcode,
    Product? existing,
    FieldErrors errors,
  ) async {
    if (sku != null) {
      final taken = await _products.skuExists(sku, excludeId: existing?.id);
      if (taken.isFailure) {
        return taken.failureOrNull;
      }
      if (taken.valueOrNull ?? false) {
        errors.add('sku', 'SKU "$sku" is already used by another product.');
      }
    }
    if (barcode != null) {
      final taken = await _products.barcodeExists(
        barcode,
        excludeId: existing?.id,
      );
      if (taken.isFailure) {
        return taken.failureOrNull;
      }
      if (taken.valueOrNull ?? false) {
        errors.add('barcode', 'Barcode is already used by another product.');
      }
    }
    return null;
  }
}
