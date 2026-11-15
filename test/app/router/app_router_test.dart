import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/app.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/app/shell/coming_soon_page.dart';
import 'package:inventrix/app/shell/not_found_page.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:inventrix/features/inventory/presentation/pages/inventory_page.dart';
import 'package:inventrix/features/products/presentation/pages/products_page.dart';
import 'package:inventrix/features/sales/presentation/pages/sales_page.dart';

import '../../support/test_locator.dart';

Future<GoRouter> pumpApp(
  WidgetTester tester, {
  Size size = const Size(400, 900),
  String initialLocation = RoutePaths.dashboard,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = TestWiring().router(initialLocation: initialLocation);
  await tester.pumpWidget(InventrixApp(router: router));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('opens the dashboard directly without authentication', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(DashboardPage), findsOneWidget);
    expect(find.text('Welcome to Inventrix'), findsOneWidget);
    expect(find.text(AppConstants.localDataWarning), findsOneWidget);
  });

  testWidgets('root path redirects to the dashboard', (tester) async {
    await pumpApp(tester, initialLocation: '/');
    expect(find.byType(DashboardPage), findsOneWidget);
  });

  testWidgets('shows a bottom navigation bar on narrow screens', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('shows a navigation rail on wide screens', (tester) async {
    await pumpApp(tester, size: const Size(1000, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('switches between primary sections', (tester) async {
    await pumpApp(tester);
    Future<void> open(String label) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
      );
      await tester.pumpAndSettle();
    }

    await open('Products');
    expect(find.byType(ProductsPage), findsOneWidget);
    await open('Inventory');
    expect(find.byType(InventoryPage), findsOneWidget);
    await open('Sales');
    expect(find.byType(SalesPage), findsOneWidget);
  });

  testWidgets('More lists secondary sections and opens one', (tester) async {
    await pumpApp(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('More'),
      ),
    );
    await tester.pumpAndSettle();
    for (final title in ['Purchases', 'Customers', 'Backup', 'Settings']) {
      expect(find.text(title), findsOneWidget);
    }
    // Expenses (Phase 8) is a real screen now.
    await tester.tap(find.text('Expenses'));
    await tester.pumpAndSettle();
    expect(find.byType(ComingSoonPage), findsNothing);
    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('unknown routes show the not-found page', (tester) async {
    final router = await pumpApp(tester);
    router.go('/does-not-exist');
    await tester.pumpAndSettle();
    expect(find.byType(NotFoundPage), findsOneWidget);
    await tester.tap(find.text('Go to dashboard'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
  });
}
