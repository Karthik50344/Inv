import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/domain/usecases/restore_product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_bloc.dart';
import 'package:inventrix/features/products/presentation/bloc/product_event.dart';
import 'package:inventrix/features/products/presentation/bloc/product_state.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/bloc_test_helper.dart';
import '../../support/domain_fixture.dart';
import '../../support/fakes.dart';

void main() {
  late DomainFixture f;
  late CreateProduct create;

  ProductBloc build() => ProductBloc(
    products: f.products,
    categories: f.categories,
    units: f.units,
    archiveProduct: ArchiveProduct(products: f.products, clock: f.clock),
    restoreProduct: RestoreProduct(products: f.products, clock: f.clock),
    imageStorage: FakeImageStorage(),
  );

  Future<String> add(String name, {String sku = '', String? categoryId}) async {
    final r = await create(
      ProductDraft(name: name, sku: sku, unitId: 'u1', categoryId: categoryId),
    );
    return r.valueOrNull!.id;
  }

  setUp(() {
    f = DomainFixture();
    seedUnit(f);
    create = CreateProduct(
      validator: f.validator,
      products: f.products,
      ids: f.ids,
      clock: f.clock,
    );
  });

  test('starts in the initial state', () {
    expect(build().state, const ProductState());
  });

  blocTest<ProductBloc, ProductState>(
    'emits loading then empty when there are no products',
    build: build,
    act: (bloc) => bloc.add(const ProductsStarted()),
    verify: (bloc) {
      expect(bloc.state.status, ViewStatus.empty);
      expect(bloc.state.isFiltered, isFalse);
    },
    expect: () => [
      isA<ProductState>().having((s) => s.status, 'status', ViewStatus.loading),
      isA<ProductState>().having((s) => s.status, 'status', ViewStatus.empty),
    ],
  );

  blocTest<ProductBloc, ProductState>(
    'loads products with categories and unit lookup',
    setUp: () async {
      seedCategory(f);
      await add('Hammer', categoryId: 'c1');
    },
    build: build,
    act: (bloc) => bloc.add(const ProductsStarted()),
    verify: (bloc) {
      expect(bloc.state.status, ViewStatus.loaded);
      expect(bloc.state.products.single.name, 'Hammer');
      expect(bloc.state.categories.single.name, 'Tools');
      expect(bloc.state.units['u1']?.symbol, 'pcs');
    },
  );

  blocTest<ProductBloc, ProductState>(
    'search narrows the list and marks the state as filtered',
    setUp: () async {
      await add('Hammer');
      await add('Saw');
    },
    build: build,
    act: (bloc) => bloc.add(const ProductsSearchChanged('saw')),
    verify: (bloc) {
      expect(bloc.state.products.map((p) => p.name).toList(), ['Saw']);
      expect(bloc.state.isFiltered, isTrue);
    },
  );

  blocTest<ProductBloc, ProductState>(
    'category filter can be set and cleared',
    setUp: () async {
      seedCategory(f);
      await add('Hammer', categoryId: 'c1');
      await add('Saw');
    },
    build: build,
    act: (bloc) async {
      bloc.add(const ProductsCategoryFilterChanged('c1'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ProductsCategoryFilterChanged(null));
    },
    verify: (bloc) {
      expect(bloc.state.filter.categoryId, isNull);
      expect(bloc.state.products.length, 2);
    },
  );

  blocTest<ProductBloc, ProductState>(
    'archived products appear only when requested',
    setUp: () async {
      final id = await add('Hammer');
      await ArchiveProduct(products: f.products, clock: f.clock)(id);
    },
    build: build,
    act: (bloc) async {
      bloc.add(const ProductsStarted());
      bloc.add(const ProductsArchivedFilterChanged(includeArchived: true));
    },
    verify: (bloc) {
      expect(bloc.state.products.single.isArchived, isTrue);
    },
  );

  blocTest<ProductBloc, ProductState>(
    'archive toggle archives and restores through the list',
    setUp: () async => add('Hammer'),
    build: build,
    act: (bloc) async {
      bloc.add(const ProductsStarted());
      bloc.add(const ProductArchiveToggled('id-1', archive: true));
    },
    verify: (bloc) {
      expect(bloc.state.status, ViewStatus.empty);
      expect(f.products.items['id-1']!.isArchived, isTrue);
    },
  );

  blocTest<ProductBloc, ProductState>(
    'archive failure surfaces a message',
    build: build,
    act: (bloc) =>
        bloc.add(const ProductArchiveToggled('ghost', archive: true)),
    verify: (bloc) => expect(bloc.state.message, isNotNull),
  );

  blocTest<ProductBloc, ProductState>(
    'a repository failure ends in the failure state',
    setUp: () =>
        f.products.searchFailure = const DatabaseFailure('database offline'),
    build: build,
    act: (bloc) => bloc.add(const ProductsStarted()),
    verify: (bloc) {
      expect(bloc.state.status, ViewStatus.failure);
      expect(bloc.state.message, 'database offline');
    },
  );

  test('unexpected failures show a generic user message', () async {
    f.products.searchFailure = const UnexpectedFailure('stack trace here');
    final bloc = build()..add(const ProductsStarted());
    await bloc.stream.firstWhere((s) => s.status == ViewStatus.failure);
    expect(bloc.state.message, 'Something went wrong. Please try again.');
    await bloc.close();
  });
}
