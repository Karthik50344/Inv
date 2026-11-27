import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/app.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/features/onboarding/presentation/pages/intro_page.dart';

GoRouter _router() => GoRouter(
  initialLocation: RoutePaths.intro,
  routes: [
    GoRoute(path: RoutePaths.intro, builder: (_, _) => const IntroPage()),
    GoRoute(
      path: RoutePaths.dashboard,
      builder: (_, _) => const Scaffold(body: Text('dashboard')),
    ),
  ],
);

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(InventrixApp(router: _router()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on the first slide with Next and Skip', (tester) async {
    await _pump(tester);
    expect(find.text('Welcome to Inventrix'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byKey(const Key('intro_skip')), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('Next moves forward and the last slide shows Continue', (
    tester,
  ) async {
    await _pump(tester);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const Key('intro_next')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Your data stays with you'), findsOneWidget);
    expect(find.text(AppConstants.localDataWarning), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byKey(const Key('intro_skip')).hitTestable(), findsNothing);
  });

  testWidgets('swiping left changes the slide', (tester) async {
    await _pump(tester);
    await tester.fling(
      find.byKey(const Key('intro_pages')),
      const Offset(-400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('Products and stock'), findsOneWidget);
  });

  testWidgets('Skip jumps to the last slide', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('intro_skip')));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Continue opens the dashboard', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('intro_skip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('intro_next')));
    await tester.pumpAndSettle();
    expect(find.text('dashboard'), findsOneWidget);
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    await tester.tap(find.byKey(const Key('intro_skip')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
