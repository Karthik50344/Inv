import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';
import 'package:inventrix/features/products/presentation/pages/product_detail_page.dart';
import 'package:inventrix/features/products/presentation/pages/product_form_page.dart';
import 'package:inventrix/features/products/presentation/pages/products_page.dart';
import 'package:flutter/material.dart';
import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

void main() {
  late TestWiring wiring;

  setUp(() {
    wiring = TestWiring()
      ..addUnit()
      ..addCategory();
  });

  Future<void> seed(String name, {String sku = '', String? categoryId}) =>
      wiring.locator<CreateProduct>()(
        ProductDraft(
          name: name,
          sku: sku,
          unitId: 'u1',
          categoryId: categoryId,
          sellingPrice: '10',
        ),
      );

  testWidgets('empty product list', (tester) async {
    await pumpInventrix(tester, wiring, location: RoutePaths.products);
    expect(find.text('No products yet'), findsOneWidget);
  });

  testWidgets('lists products and filters by search', (tester) async {
    await seed('Hammer', sku: 'H-1');
    await seed('Saw', sku: 'S-1');
    await pumpInventrix(tester, wiring, location: RoutePaths.products);
    expect(find.text('Hammer'), findsOneWidget);
    expect(find.text('Saw'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'saw');
    await tester.pumpAndSettle();
    expect(find.text('Hammer'), findsNothing);
    expect(find.text('Saw'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matching products'), findsOneWidget);
  });

  testWidgets('creates a product through the form', (tester) async {
    await pumpInventrix(tester, wiring, location: RoutePaths.products);
    await tapKey(tester, 'add_product');
    expect(find.byType(ProductFormPage), findsOneWidget);

    await enter(tester, 'product_name', 'Hammer');
    await enter(tester, 'product_selling', '99.5');
    await tapKey(tester, 'product_unit');
    await tester.tap(find.text('Unit pcs (pcs)').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'save_product');

    expect(find.byType(ProductsPage), findsOneWidget);
    expect(find.text('Hammer'), findsOneWidget);
    final saved = wiring.products.items.values.single;
    expect(saved.sku, 'P-000001');
    expect(saved.sellingPrice.minorUnits, 9950);
  });

  testWidgets('client validation blocks an empty form', (tester) async {
    await pumpInventrix(tester, wiring, location: '${RoutePaths.products}/new');
    await tapKey(tester, 'save_product');
    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.text('Select a unit.'), findsOneWidget);
    expect(wiring.products.items, isEmpty);
  });

  testWidgets('server-side errors appear on the field', (tester) async {
    await seed('Hammer', sku: 'H-1');
    await pumpInventrix(tester, wiring, location: '${RoutePaths.products}/new');
    await enter(tester, 'product_name', 'Other');
    await enter(tester, 'product_sku', 'h-1');
    await tapKey(tester, 'product_unit');
    await tester.tap(find.text('Unit pcs (pcs)').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'save_product');
    expect(find.textContaining('already used'), findsOneWidget);
    expect(wiring.products.items.length, 1);
  });

  testWidgets('opens details and edits a product', (tester) async {
    await seed('Hammer', sku: 'H-1');
    await pumpInventrix(tester, wiring, location: RoutePaths.products);
    await tester.tap(find.text('Hammer'));
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailPage), findsOneWidget);
    expect(find.text('H-1'), findsOneWidget);

    await tapKey(tester, 'edit_product');
    await enter(tester, 'product_name', 'Big hammer');
    await tapKey(tester, 'save_product');
    expect(find.byType(ProductDetailPage), findsOneWidget);
    expect(find.text('Big hammer'), findsWidgets);
    expect(wiring.products.items.values.single.name, 'Big hammer');
  });

  testWidgets('archives a product from its details', (tester) async {
    await seed('Hammer', sku: 'H-1');
    await pumpInventrix(tester, wiring, location: RoutePaths.products);
    await tester.tap(find.text('Hammer'));
    await tester.pumpAndSettle();
    await tapKey(tester, 'toggle_archive_product');
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    expect(wiring.products.items.values.single.isArchived, isTrue);
    expect(find.text('Archived'), findsOneWidget);
  });

  testWidgets('an invalid product id shows a not-found message', (
    tester,
  ) async {
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/ghost',
    );
    expect(find.text('Product not found'), findsOneWidget);
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/ghost/edit',
    );
    expect(find.text('Product not found'), findsOneWidget);
  });
}
