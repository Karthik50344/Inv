import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';

import 'data_test_support.dart';

void main() {
  late DataHarness h;

  setUp(() => h = DataHarness());
  tearDown(() => h.close());

  group('settings', () {
    test('reads the seeded currency', () async {
      final config = (await h.settings.getCurrencyConfig()).valueOrNull!;
      expect(config.currencyCode, 'INR');
      expect(config.decimalPlaces, 2);
    });

    test('invalid stored settings fail instead of guessing', () async {
      await h.db.customStatement(
        "UPDATE app_settings SET value = 'rupees' WHERE key = 'currency_code'",
      );
      final result = await h.settings.getCurrencyConfig();
      expect(result.failureOrNull, isA<DatabaseFailure>());
    });
  });

  group('tax rates', () {
    TaxRate rate(String id, String name, {int bp = 1800}) => TaxRate(
      id: id,
      name: name,
      rateBp: bp,
      isExempt: false,
      createdAt: t0,
      updatedAt: t0,
    );

    test('create, list, get and name lookup (case-insensitive)', () async {
      expect((await h.taxRates.create(rate('t1', 'GST 18'))).isSuccess, isTrue);
      expect((await h.taxRates.list()).valueOrNull!.single.rateBp, 1800);
      expect((await h.taxRates.getById('t1')).valueOrNull?.name, 'GST 18');
      expect((await h.taxRates.nameExists('gst 18')).valueOrNull, isTrue);
      expect((await h.taxRates.nameExists('other')).valueOrNull, isFalse);
      expect(
        (await h.taxRates.getById('ghost')).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('categories', () {
    test('create, read, update and search', () async {
      await h.categories.create(category());
      await h.categories.create(category(id: 'c2', name: 'Paint'));
      final all = (await h.categories.search()).valueOrNull!;
      expect(all.map((c) => c.name).toList(), ['Paint', 'Tools']);
      final found = (await h.categories.search(query: 'ool')).valueOrNull!;
      expect(found.single.id, 'c1');

      await h.categories.update(
        category().withDetails(name: 'Power tools', updatedAt: t0),
      );
      expect(
        (await h.categories.getById('c1')).valueOrNull?.name,
        'Power tools',
      );
    });

    test('name uniqueness: case-insensitive among active only', () async {
      await h.categories.create(category());
      expect((await h.categories.nameExists('TOOLS')).valueOrNull, isTrue);
      expect(
        (await h.categories.nameExists('tools', excludeId: 'c1')).valueOrNull,
        isFalse,
      );
      final dup = await h.categories.create(category(id: 'c2', name: 'tools'));
      expect(dup.failureOrNull, isA<DuplicateEntryFailure>());

      await h.categories.update(category().archived(t0));
      expect((await h.categories.nameExists('tools')).valueOrNull, isFalse);
      expect(
        (await h.categories.create(
          category(id: 'c3', name: 'Tools'),
        )).isSuccess,
        isTrue,
      );
    });

    test('archived categories are hidden unless requested', () async {
      await h.categories.create(category(archived: t0));
      expect((await h.categories.search()).valueOrNull, isEmpty);
      expect(
        (await h.categories.search(includeArchived: true)).valueOrNull!.length,
        1,
      );
    });

    test('missing records produce NotFound', () async {
      expect(
        (await h.categories.getById('ghost')).failureOrNull,
        isA<NotFoundFailure>(),
      );
      expect(
        (await h.categories.update(category(id: 'ghost'))).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('counts products by category, active only on request', () async {
      await h.units.create(unit());
      await h.categories.create(category());
      await h.products.create(product(categoryId: 'c1'));
      await h.products.create(
        product(id: 'p2', sku: 'S2', categoryId: 'c1', archived: t0),
      );
      expect(
        (await h.categories.countProducts('c1', activeOnly: false)).valueOrNull,
        2,
      );
      expect(
        (await h.categories.countProducts('c1', activeOnly: true)).valueOrNull,
        1,
      );
    });
  });

  group('units', () {
    test('create, search by name or symbol, update', () async {
      await h.units.create(unit(symbol: 'kg', places: 3));
      await h.units.create(unit(id: 'u2', symbol: 'pcs'));
      expect((await h.units.search(query: 'kg')).valueOrNull!.single.id, 'u1');
      expect(
        (await h.units.search(query: 'Unit pcs')).valueOrNull!.single.id,
        'u2',
      );
      await h.units.update(
        unit(symbol: 'kg', places: 3).withDetails(
          name: 'Kilo',
          symbol: 'kg',
          decimalPlaces: 3,
          updatedAt: t0,
        ),
      );
      expect((await h.units.getById('u1')).valueOrNull?.name, 'Kilo');
    });

    test('symbols are unique case-insensitively, archived included', () async {
      await h.units.create(unit(symbol: 'kg'));
      expect((await h.units.symbolExists('KG')).valueOrNull, isTrue);
      expect(
        (await h.units.symbolExists('kg', excludeId: 'u1')).valueOrNull,
        isFalse,
      );
      await h.units.update(unit(symbol: 'kg').archived(t0));
      expect((await h.units.symbolExists('kg')).valueOrNull, isTrue);
      final dup = await h.units.create(unit(id: 'u2', symbol: 'kg'));
      expect(dup.failureOrNull, isA<DuplicateEntryFailure>());
    });

    test('rejects out-of-range precision at the database level', () async {
      final result = await h.units.create(unit(places: 4));
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('counts products using a unit', () async {
      await h.units.create(unit());
      await h.products.create(product());
      expect(
        (await h.units.countProducts('u1', activeOnly: true)).valueOrNull,
        1,
      );
    });
  });
}
