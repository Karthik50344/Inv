import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/categories/domain/usecases/archive_category.dart';
import 'package:inventrix/features/categories/domain/usecases/create_category.dart';
import 'package:inventrix/features/categories/domain/usecases/restore_category.dart';
import 'package:inventrix/features/categories/domain/usecases/update_category.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';

import '../../support/domain_fixture.dart';

void main() {
  late DomainFixture f;
  late CreateCategory create;
  late UpdateCategory update;
  late ArchiveCategory archive;
  late RestoreCategory restore;

  setUp(() {
    f = DomainFixture();
    create = CreateCategory(
      repository: f.categories,
      ids: f.ids,
      clock: f.clock,
    );
    update = UpdateCategory(repository: f.categories, clock: f.clock);
    archive = ArchiveCategory(repository: f.categories, clock: f.clock);
    restore = RestoreCategory(repository: f.categories, clock: f.clock);
  });

  test('creates a trimmed category with timestamps', () async {
    final r = await create(name: '  Hardware ', description: '  ');
    final c = r.valueOrNull!;
    expect(c.name, 'Hardware');
    expect(c.description, isNull);
    expect(c.createdAt, f.clock.now());
    expect(f.categories.items.length, 1);
  });

  test('rejects blank, long and duplicate names', () async {
    expect(fieldErrorsOf(await create(name: ' ')).containsKey('name'), isTrue);
    expect(
      fieldErrorsOf(await create(name: 'x' * 81)).containsKey('name'),
      isTrue,
    );
    await create(name: 'Tools');
    final dup = await create(name: 'TOOLS');
    expect(fieldErrorsOf(dup).containsKey('name'), isTrue);
    expect(f.categories.items.length, 1);
  });

  test('update changes details and keeps identity', () async {
    final c = (await create(name: 'Tools')).valueOrNull!;
    f.clock.advance(const Duration(hours: 1));
    final r = await update(id: c.id, name: 'Power tools', description: 'x');
    expect(r.valueOrNull?.name, 'Power tools');
    expect(r.valueOrNull?.createdAt, c.createdAt);
    expect(r.valueOrNull?.updatedAt, f.clock.now());
  });

  test('update rejects a name used by another active category', () async {
    await create(name: 'A');
    final b = (await create(name: 'B')).valueOrNull!;
    final r = await update(id: b.id, name: 'a');
    expect(fieldErrorsOf(r).containsKey('name'), isTrue);
  });

  test('update of a missing category is NotFound', () async {
    final r = await update(id: 'nope', name: 'X');
    expect(r.failureOrNull, isA<NotFoundFailure>());
  });

  test('archive is blocked while active products use the category', () async {
    final c = (await create(name: 'Tools')).valueOrNull!;
    f.categories.items[c.id] = c;
    final productId = await _addProduct(f, categoryId: c.id);
    final blocked = await archive(c.id);
    expect(blocked.failureOrNull, isA<ValidationFailure>());
    expect(f.categories.items[c.id]!.isArchived, isFalse);

    await ArchiveProduct(products: f.products, clock: f.clock)(productId);
    final ok = await archive(c.id);
    expect(ok.isSuccess, isTrue);
    expect(f.categories.items[c.id]!.isArchived, isTrue);
  });

  test('archive is idempotent', () async {
    final c = (await create(name: 'Tools')).valueOrNull!;
    await archive(c.id);
    expect((await archive(c.id)).isSuccess, isTrue);
  });

  test('restore fails when an active category took the name', () async {
    final c = (await create(name: 'Tools')).valueOrNull!;
    await archive(c.id);
    await create(name: 'Tools');
    final r = await restore(c.id);
    expect(r.failureOrNull, isA<DuplicateEntryFailure>());
    expect(f.categories.items[c.id]!.isArchived, isTrue);
  });

  test('restore brings an archived category back', () async {
    final c = (await create(name: 'Tools')).valueOrNull!;
    await archive(c.id);
    expect((await restore(c.id)).isSuccess, isTrue);
    expect(f.categories.items[c.id]!.isArchived, isFalse);
  });

  test('archived names may be reused by new categories', () async {
    final c = (await create(name: 'Tools')).valueOrNull!;
    await archive(c.id);
    expect((await create(name: 'Tools')).isSuccess, isTrue);
  });
}

Future<String> _addProduct(DomainFixture f, {String? categoryId}) async {
  seedUnit(f);
  final r = await CreateProduct(
    validator: f.validator,
    products: f.products,
    ids: f.ids,
    clock: f.clock,
  )(ProductDraft(name: 'Hammer', unitId: 'u1', categoryId: categoryId));
  return r.valueOrNull!.id;
}
