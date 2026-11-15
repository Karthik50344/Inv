import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/router/route_paths.dart';

import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

void main() {
  late TestWiring wiring;

  setUp(() => wiring = TestWiring());

  testWidgets('empty state offers common units', (tester) async {
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/units',
    );
    expect(find.text('No units yet'), findsOneWidget);
    await tapKey(tester, 'add_common_units');
    expect(wiring.units.items.length, 8);
    expect(find.text('Kilogram (kg)'), findsOneWidget);
  });

  testWidgets('creates a unit with its precision', (tester) async {
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/units',
    );
    await tapKey(tester, 'add_unit');
    await enter(tester, 'unit_name', 'Metre');
    await enter(tester, 'unit_symbol', 'm');
    await tapKey(tester, 'unit_save');
    expect(find.text('Metre (m)'), findsOneWidget);
    expect(wiring.units.items.values.single.decimalPlaces, 0);
  });

  testWidgets('shows validation errors in the dialog', (tester) async {
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/units',
    );
    await tapKey(tester, 'add_unit');
    await tapKey(tester, 'unit_save');
    expect(find.text('Name is required.'), findsOneWidget);
    expect(find.text('Symbol is required.'), findsOneWidget);
  });

  testWidgets('rejects a duplicate symbol', (tester) async {
    wiring.addUnit(symbol: 'kg', decimals: 3);
    await pumpInventrix(
      tester,
      wiring,
      location: '${RoutePaths.products}/units',
    );
    await tapKey(tester, 'add_unit');
    await enter(tester, 'unit_name', 'Kilo');
    await enter(tester, 'unit_symbol', 'KG');
    await tapKey(tester, 'unit_save');
    expect(find.textContaining('already exists'), findsOneWidget);
  });
}
