import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';

import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

void main() {
  late TestWiring wiring;

  setUp(() => wiring = TestWiring());

  testWidgets('shows an empty state, then creates a category', (tester) async {
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/categories',
    );
    expect(find.text('No categories yet'), findsOneWidget);

    await tapKey(tester, 'add_category');
    await enter(tester, 'category_name', 'Hardware');
    await tapKey(tester, 'category_save');

    expect(find.text('Hardware'), findsOneWidget);
    expect(find.text('No categories yet'), findsNothing);
    expect(wiring.categories.items.length, 1);
  });

  testWidgets('shows validation errors inside the dialog', (tester) async {
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/categories',
    );
    await tapKey(tester, 'add_category');
    await tapKey(tester, 'category_save');
    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.byKey(const Key('category_save')), findsOneWidget);
    expect(wiring.categories.items, isEmpty);
  });

  testWidgets('rejects a duplicate name with a field error', (tester) async {
    wiring.addCategory(name: 'Tools');
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/categories',
    );
    await tapKey(tester, 'add_category');
    await enter(tester, 'category_name', 'tools');
    await tapKey(tester, 'category_save');
    expect(find.textContaining('already exists'), findsOneWidget);
    expect(wiring.categories.items.length, 1);
  });

  testWidgets('search narrows the list', (tester) async {
    wiring
      ..addCategory(name: 'Tools')
      ..addCategory(id: 'c2', name: 'Paint');
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/categories',
    );
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Paint'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'pai');
    await tester.pumpAndSettle();
    expect(find.text('Tools'), findsNothing);
    expect(find.text('Paint'), findsOneWidget);
  });

  testWidgets('archives a category after confirmation', (tester) async {
    wiring.addCategory();
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/categories',
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('Archive category?'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(wiring.categories.items['c1']!.isArchived, isTrue);
    expect(find.text('No categories yet'), findsOneWidget);
  });

  testWidgets('archiving is blocked while active products use the category', (
    tester,
  ) async {
    wiring
      ..addUnit()
      ..addCategory();
    await wiring.locator<CreateProduct>()(
      const ProductDraft(name: 'Hammer', unitId: 'u1', categoryId: 'c1'),
    );
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/categories',
    );
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cannot archive'), findsOneWidget);
    expect(wiring.categories.items['c1']!.isArchived, isFalse);
  });
}
