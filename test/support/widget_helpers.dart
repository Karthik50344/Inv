import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/app.dart';

import 'test_locator.dart';

/// Pumps the whole app (real router, BLoCs and use cases) on top of fake
/// repositories and returns the router for navigation.
Future<GoRouter> pumpInventrix(
  WidgetTester tester,
  TestWiring wiring, {
  String location = '/dashboard',
  Size size = const Size(900, 1600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = wiring.router(initialLocation: location);
  await tester.pumpWidget(InventrixApp(router: router));
  await tester.pumpAndSettle();
  return router;
}

/// Enters [text] into the field with [key].
Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

/// Taps the widget with [key] and settles animations.
Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}
