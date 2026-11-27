import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

Future<double> _contentWidth(WidgetTester tester, Size screen) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppContentWidth(
          child: ListView(children: const [SizedBox(key: Key('row'), height: 10)]),
        ),
      ),
    ),
  );
  return tester.getSize(find.byKey(const Key('row'))).width;
}

void main() {
  testWidgets('phones keep the full width', (tester) async {
    expect(await _contentWidth(tester, const Size(390, 800)), 390);
  });

  testWidgets('small phones do not overflow', (tester) async {
    expect(await _contentWidth(tester, const Size(320, 568)), 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablets are capped and centered', (tester) async {
    expect(
      await _contentWidth(tester, const Size(1200, 800)),
      AppDimensions.maxContentWidth,
    );
    final left = tester.getTopLeft(find.byKey(const Key('row'))).dx;
    expect(left, (1200 - AppDimensions.maxContentWidth) / 2);
  });
}
