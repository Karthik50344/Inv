import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/domain/usecases/restore_product.dart';
import 'package:inventrix/features/products/domain/usecases/update_product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/settings/domain/usecases/create_tax_rate.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/domain_fixture.dart';
import '../../support/fakes.dart';

void main() {
  late DomainFixture f;
  late FakeImageStorage images;

  ProductFormCubit buildForm() => ProductFormCubit(
    products: f.products,
    categories: f.categories,
    units: f.units,
    taxRates: f.taxRates,
    settings: f.settings,
    createProduct: CreateProduct(
      validator: f.validator,
      products: f.products,
      ids: f.ids,
      clock: f.clock,
    ),
    updateProduct: UpdateProduct(
      validator: f.validator,
      products: f.products,
      clock: f.clock,
    ),
    createTaxRate: CreateTaxRate(
      repository: f.taxRates,
      ids: f.ids,
      clock: f.clock,
    ),
    imageStorage: images,
  );

  ProductDetailCubit buildDetail() => ProductDetailCubit(
    products: f.products,
    categories: f.categories,
    units: f.units,
    taxRates: f.taxRates,
    archiveProduct: ArchiveProduct(products: f.products, clock: f.clock),
    restoreProduct: RestoreProduct(products: f.products, clock: f.clock),
    imageStorage: images,
  );

  setUp(() {
    f = DomainFixture();
    images = FakeImageStorage();
    seedUnit(f);
  });

  group('ProductFormCubit', () {
    test('starts loading', () {
      expect(buildForm().state.loadStatus, FormLoadStatus.loading);
    });

    test('load in create mode exposes reference data and currency', () async {
      seedCategory(f);
      final cubit = buildForm();
      await cubit.load();
      expect(cubit.state.loadStatus, FormLoadStatus.ready);
      expect(cubit.state.isEditing, isFalse);
      expect(cubit.state.units.single.symbol, 'pcs');
      expect(cubit.state.categories.single.name, 'Tools');
      expect(cubit.state.currency?.currencyCode, 'INR');
    });

    test(
      'archived reference data is hidden unless the product uses it',
      () async {
        seedUnit(f, id: 'old', symbol: 'old', archived: true);
        seedCategory(f, id: 'old', name: 'Old', archived: true);
        final cubit = buildForm();
        await cubit.load();
        expect(cubit.state.units.map((u) => u.id).toList(), ['u1']);
        expect(cubit.state.categories, isEmpty);
      },
    );

    test('load in edit mode returns the product', () async {
      final created = await CreateProduct(
        validator: f.validator,
        products: f.products,
        ids: f.ids,
        clock: f.clock,
      )(const ProductDraft(name: 'Hammer', unitId: 'u1', sellingPrice: '9.5'));
      final cubit = buildForm();
      await cubit.load(productId: created.valueOrNull!.id);
      expect(cubit.state.isEditing, isTrue);
      expect(cubit.state.product?.sellingPrice.minorUnits, 950);
    });

    test('unknown product id ends in notFound', () async {
      final cubit = buildForm();
      await cubit.load(productId: 'ghost');
      expect(cubit.state.loadStatus, FormLoadStatus.notFound);
    });

    test('a repository failure ends in failure', () async {
      f.categories.searchFailure = const DatabaseFailure('offline');
      final cubit = buildForm();
      await cubit.load();
      expect(cubit.state.loadStatus, FormLoadStatus.failure);
      expect(cubit.state.message, 'offline');
    });

    test('submit with invalid data exposes field errors', () async {
      final cubit = buildForm();
      await cubit.load();
      await cubit.submit(const ProductDraft(name: '', unitId: ''));
      expect(cubit.state.submitStatus, SubmitStatus.validationError);
      expect(cubit.state.fieldErrors.containsKey('name'), isTrue);
      expect(cubit.state.fieldErrors.containsKey('unitId'), isTrue);
      expect(f.products.items, isEmpty);
    });

    test('submit success creates the product and reports its id', () async {
      final cubit = buildForm();
      await cubit.load();
      await cubit.submit(
        const ProductDraft(name: 'Hammer', unitId: 'u1', sku: 'ham-1'),
      );
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(cubit.state.savedProductId, isNotNull);
      expect(f.products.items.values.single.sku, 'HAM-1');
    });

    test('submit in edit mode updates the existing product', () async {
      final created =
          (await CreateProduct(
                validator: f.validator,
                products: f.products,
                ids: f.ids,
                clock: f.clock,
              )(const ProductDraft(name: 'Hammer', unitId: 'u1', sku: 'H-1')))
              .valueOrNull!;
      final cubit = buildForm();
      await cubit.load(productId: created.id);
      await cubit.submit(
        const ProductDraft(name: 'Big hammer', unitId: 'u1', sku: 'H-1'),
      );
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(f.products.items.length, 1);
      expect(f.products.items[created.id]!.name, 'Big hammer');
    });

    test('attachImage stores the file and removeImage clears it', () async {
      final cubit = buildForm();
      await cubit.load();
      await cubit.attachImage('/picked/photo.jpg');
      expect(cubit.state.imagePath, 'product_images/img_1.jpg');
      expect(images.stored, ['/picked/photo.jpg']);
      cubit.removeImage();
      expect(cubit.state.imagePath, isNull);
    });

    test(
      'attachImage failure reports a message and keeps the old image',
      () async {
        images.failure = const ValidationFailure(
          'Choose a JPG, PNG or WebP image.',
        );
        final cubit = buildForm();
        await cubit.load();
        await cubit.attachImage('/picked/file.txt');
        expect(cubit.state.imagePath, isNull);
        expect(cubit.state.message, 'Choose a JPG, PNG or WebP image.');
      },
    );

    test('createTaxRate makes the new rate selectable', () async {
      final cubit = buildForm();
      await cubit.load();
      final result = await cubit.createTaxRate(
        name: 'GST 18',
        ratePercent: '18',
      );
      expect(result.isSuccess, isTrue);
      expect(cubit.state.taxRates.single.rateBp, 1800);
      final bad = await cubit.createTaxRate(name: '', ratePercent: 'x');
      expect(bad.failureOrNull, isA<ValidationFailure>());
      expect(cubit.state.taxRates.length, 1);
    });
  });

  group('ProductDetailCubit', () {
    test('loads a product with category, unit and tax rate', () async {
      seedCategory(f);
      final created =
          (await CreateProduct(
                validator: f.validator,
                products: f.products,
                ids: f.ids,
                clock: f.clock,
              )(
                const ProductDraft(
                  name: 'Hammer',
                  unitId: 'u1',
                  categoryId: 'c1',
                ),
              ))
              .valueOrNull!;
      final cubit = buildDetail();
      await cubit.load(created.id);
      expect(cubit.state.status, DetailStatus.loaded);
      expect(cubit.state.category?.name, 'Tools');
      expect(cubit.state.unit?.symbol, 'pcs');
    });

    test('an invalid id ends in notFound', () async {
      final cubit = buildDetail();
      await cubit.load('ghost');
      expect(cubit.state.status, DetailStatus.notFound);
    });

    test('archive and restore reload the product', () async {
      final created = (await CreateProduct(
        validator: f.validator,
        products: f.products,
        ids: f.ids,
        clock: f.clock,
      )(const ProductDraft(name: 'Hammer', unitId: 'u1'))).valueOrNull!;
      final cubit = buildDetail();
      await cubit.load(created.id);
      await cubit.archive();
      expect(cubit.state.product?.isArchived, isTrue);
      await cubit.restore();
      expect(cubit.state.product?.isArchived, isFalse);
    });
  });
}
