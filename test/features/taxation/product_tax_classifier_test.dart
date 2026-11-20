import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/product_tax_classifier.dart';

import 'tax_test_fixtures.dart';

void main() {
  final cfg = config(
    categories: [category(kCategory), category('assigned'), category('exempt-cat', treatment: TaxTreatment.exempt)],
    overrides: const [
      TaxOverride(id: 'o1', name: 'Export', taxCategoryId: 'exempt-cat', reason: 'Export certificate'),
      TaxOverride(id: 'o2', name: 'Old', taxCategoryId: 'exempt-cat', reason: 'x', isActive: false),
    ],
  );

  test('an explicit override wins over the product category', () {
    final r = ProductTaxClassifier.resolve(
      configuration: cfg,
      taxProfileId: kProfile,
      productTaxCategoryId: 'assigned',
      productTaxOverrideId: 'o1',
    ).valueOrNull!;
    expect(r.categoryId, 'exempt-cat');
    expect(r.source, TaxCategorySource.explicitOverride);
    expect(r.overrideId, 'o1');
  });

  test('the assigned category wins over the profile default', () {
    final r = ProductTaxClassifier.resolve(
      configuration: cfg,
      taxProfileId: kProfile,
      productTaxCategoryId: 'assigned',
    ).valueOrNull!;
    expect(r.categoryId, 'assigned');
    expect(r.source, TaxCategorySource.productAssignment);
  });

  test('a product with nothing inherits the profile default', () {
    final r = ProductTaxClassifier.resolve(
      configuration: cfg,
      taxProfileId: kProfile,
    ).valueOrNull!;
    expect(r.categoryId, kCategory);
    expect(r.source, TaxCategorySource.profileDefault);
  });

  test('no category and no profile default is a failure', () {
    final bare = config(
      profile: const TaxProfile(id: kProfile, name: 'P', regimeId: 'r1', isDefault: true),
    );
    final r = ProductTaxClassifier.resolve(configuration: bare, taxProfileId: kProfile);
    expect(r.failureOrNull, isA<TaxConfigurationFailure>());
  });

  test('a missing or inactive override fails instead of being ignored', () {
    for (final id in ['o2', 'ghost']) {
      final r = ProductTaxClassifier.resolve(
        configuration: cfg,
        taxProfileId: kProfile,
        productTaxOverrideId: id,
      );
      expect(r.failureOrNull, isA<TaxConfigurationFailure>());
    }
  });
}
