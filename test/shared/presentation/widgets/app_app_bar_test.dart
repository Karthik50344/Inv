import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  testWidgets('root screen shows the logo and a centered title', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const Scaffold(appBar: AppAppBar(title: 'Reports'))),
    );
    expect(find.byType(Image), findsOneWidget);
    final center = tester.getCenter(find.text('Reports')).dx;
    expect(center, closeTo(tester.view.physicalSize.width / 2 /
        tester.view.devicePixelRatio, 1));
  });

  testWidgets('pushed screen keeps the back button, not the logo', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    const Scaffold(appBar: AppAppBar(title: 'Detail')),
              ),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an explicit leading wins over the logo', (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          appBar: AppAppBar(title: 'X', leading: Icon(Icons.close)),
        ),
      ),
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('wide layouts leave the slot to the navigation rail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _app(const Scaffold(appBar: AppAppBar(title: 'Reports'))),
    );
    expect(find.byType(Image), findsNothing);
  });
}
