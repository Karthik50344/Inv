import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/features/settings/presentation/widgets/theme_mode_selector.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';

Widget _host(ThemeData theme, ThemePreference value, ValueChanged<ThemePreference> onChanged) =>
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: ThemeModeSelector(value: value, onChanged: onChanged),
      ),
    );

void main() {
  for (final entry in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    testWidgets('shows the three choices in the ${entry.key} theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(entry.value, ThemePreference.system, (_) {}),
      );
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);
    });
  }

  testWidgets('reports the tapped preference', (tester) async {
    ThemePreference? chosen;
    await tester.pumpWidget(
      _host(AppTheme.light(), ThemePreference.system, (v) => chosen = v),
    );
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(chosen, ThemePreference.dark);
  });

  testWidgets('has no overflow on a 320 px wide screen', (tester) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(AppTheme.dark(), ThemePreference.light, (_) {}),
    );
    expect(tester.takeException(), isNull);
  });
}
