import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/categories/domain/entities/category.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/services/product_validator.dart';

import 'fakes.dart';

/// Wires fake repositories shared by domain tests.
class DomainFixture {
  DomainFixture() {
    categories = FakeCategoryRepository(products);
    units = FakeUnitRepository(products);
    validator = ProductValidator(
      products: products,
      categories: categories,
      units: units,
      taxRates: taxRates,
      settings: settings,
    );
  }

  final clock = FakeClock();
  final ids = SequentialIds();
  final settings = FakeSettingsRepository();
  final products = FakeProductRepository();
  final taxRates = FakeTaxRateRepository();
  late final FakeCategoryRepository categories;
  late final FakeUnitRepository units;
  late final ProductValidator validator;
}

/// Field errors of a failed validation result (empty if not a validation
/// failure).
Map<String, String> fieldErrorsOf(Result<Object?> result) {
  final failure = result.failureOrNull;
  return failure is ValidationFailure ? failure.fieldErrors : const {};
}

/// Adds a unit directly to the fake repository.
UnitOfMeasure seedUnit(
  DomainFixture f, {
  String id = 'u1',
  String symbol = 'pcs',
  int decimals = 0,
  bool archived = false,
}) {
  final now = f.clock.now();
  final unit = UnitOfMeasure(
    id: id,
    name: 'Unit $symbol',
    symbol: symbol,
    decimalPlaces: decimals,
    createdAt: now,
    updatedAt: now,
    archivedAt: archived ? now : null,
  );
  f.units.items[id] = unit;
  return unit;
}

/// Adds a category directly to the fake repository.
Category seedCategory(
  DomainFixture f, {
  String id = 'c1',
  String name = 'Tools',
  bool archived = false,
}) {
  final now = f.clock.now();
  final category = Category(
    id: id,
    name: name,
    createdAt: now,
    updatedAt: now,
    archivedAt: archived ? now : null,
  );
  f.categories.items[id] = category;
  return category;
}
