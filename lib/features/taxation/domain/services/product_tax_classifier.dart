import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';

/// The tax category a product ends up with, and why.
final class EffectiveTaxCategory {
  /// Creates the answer.
  const EffectiveTaxCategory({
    required this.categoryId,
    required this.source,
    this.overrideId,
  });

  /// The category used in calculations.
  final String categoryId;

  /// Where it came from (shown on the product screen).
  final TaxCategorySource source;

  /// The override responsible, when [source] is an explicit override.
  final String? overrideId;
}

/// Decides a product's tax category: an explicit override first, then the
/// category assigned to the product, then the active profile's default. The
/// product never stores a tax amount.
abstract final class ProductTaxClassifier {
  /// Resolves the category for a product.
  static Result<EffectiveTaxCategory> resolve({
    required TaxConfiguration configuration,
    required String taxProfileId,
    String? productTaxCategoryId,
    String? productTaxOverrideId,
  }) {
    if (productTaxOverrideId != null) {
      final override = configuration.override(productTaxOverrideId);
      if (override == null || !override.isActive) {
        return const Result.failure(
          TaxConfigurationFailure(
            'The tax override on this product is missing or inactive.',
          ),
        );
      }
      return Result.success(
        EffectiveTaxCategory(
          categoryId: override.taxCategoryId,
          source: TaxCategorySource.explicitOverride,
          overrideId: override.id,
        ),
      );
    }
    if (productTaxCategoryId != null) {
      return Result.success(
        EffectiveTaxCategory(
          categoryId: productTaxCategoryId,
          source: TaxCategorySource.productAssignment,
        ),
      );
    }
    final profile = configuration.profile(taxProfileId);
    final fallback = profile?.defaultTaxCategoryId;
    if (fallback == null) {
      return const Result.failure(
        TaxConfigurationFailure(
          'This product has no tax category and the tax profile has no '
          'default category. Choose a tax category.',
        ),
      );
    }
    return Result.success(
      EffectiveTaxCategory(
        categoryId: fallback,
        source: TaxCategorySource.profileDefault,
      ),
    );
  }
}
