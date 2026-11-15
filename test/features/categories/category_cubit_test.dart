import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/categories/domain/usecases/archive_category.dart';
import 'package:inventrix/features/categories/domain/usecases/create_category.dart';
import 'package:inventrix/features/categories/domain/usecases/restore_category.dart';
import 'package:inventrix/features/categories/domain/usecases/update_category.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_cubit.dart';
import 'package:inventrix/features/categories/presentation/bloc/category_state.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/bloc_test_helper.dart';
import '../../support/domain_fixture.dart';

void main() {
  late DomainFixture f;

  CategoryCubit build() => CategoryCubit(
    repository: f.categories,
    createCategory: CreateCategory(
      repository: f.categories,
      ids: f.ids,
      clock: f.clock,
    ),
    updateCategory: UpdateCategory(repository: f.categories, clock: f.clock),
    archiveCategory: ArchiveCategory(repository: f.categories, clock: f.clock),
    restoreCategory: RestoreCategory(repository: f.categories, clock: f.clock),
  );

  setUp(() => f = DomainFixture());

  test('starts in the initial state', () {
    expect(build().state, const CategoryState());
  });

  blocTest<CategoryCubit, CategoryState>(
    'load emits loading then empty when there are no categories',
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const CategoryState(status: ViewStatus.loading),
      const CategoryState(status: ViewStatus.empty),
    ],
  );

  blocTest<CategoryCubit, CategoryState>(
    'load emits loaded with categories',
    setUp: () => seedCategory(f),
    build: build,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.status, ViewStatus.loaded);
      expect(cubit.state.categories.single.name, 'Tools');
    },
  );

  blocTest<CategoryCubit, CategoryState>(
    'load reports repository failures without leaking details',
    setUp: () => f.categories.searchFailure = const DatabaseFailure(
      'SELECT broke',
      cause: 'sql',
    ),
    build: build,
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.status, ViewStatus.failure);
      expect(cubit.state.message, 'SELECT broke');
    },
  );

  test('search filters by name', () async {
    seedCategory(f);
    seedCategory(f, id: 'c2', name: 'Paint');
    final cubit = build();
    await cubit.search('pai');
    expect(cubit.state.query, 'pai');
    expect(cubit.state.categories.map((c) => c.name).toList(), ['Paint']);
  });

  test('archived categories appear only when requested', () async {
    seedCategory(f, archived: true);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, ViewStatus.empty);
    await cubit.setIncludeArchived(value: true);
    expect(cubit.state.categories.length, 1);
  });

  test('create refreshes the list on success', () async {
    final cubit = build();
    final result = await cubit.create('Hardware', null);
    expect(result.isSuccess, isTrue);
    expect(cubit.state.categories.single.name, 'Hardware');
  });

  test('create returns validation errors and keeps the list', () async {
    final cubit = build();
    await cubit.create('Hardware', null);
    final result = await cubit.create('hardware', null);
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(cubit.state.categories.length, 1);
  });

  test('archive failure surfaces a message and keeps the category', () async {
    final c = seedCategory(f);
    await _addProduct(f, categoryId: c.id);
    final cubit = build();
    await cubit.load();
    await cubit.archive(c.id);
    expect(cubit.state.message, isNotNull);
    expect(cubit.state.categories.single.isArchived, isFalse);
  });

  test('archive then restore round-trips', () async {
    final c = seedCategory(f);
    final cubit = build();
    await cubit.archive(c.id);
    expect(cubit.state.status, ViewStatus.empty);
    await cubit.setIncludeArchived(value: true);
    await cubit.restore(c.id);
    expect(cubit.state.categories.single.isArchived, isFalse);
  });
}

Future<void> _addProduct(DomainFixture f, {required String categoryId}) async {
  seedUnit(f);
  await CreateProduct(
    validator: f.validator,
    products: f.products,
    ids: f.ids,
    clock: f.clock,
  )(ProductDraft(name: 'Hammer', unitId: 'u1', categoryId: categoryId));
}
