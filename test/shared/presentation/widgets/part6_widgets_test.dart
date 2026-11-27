import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/features/settings/presentation/widgets/settings_tiles.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

Widget _host(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};

  for (final entry in themes.entries) {
    group('in ${entry.key} theme', () {
      testWidgets('AppFactsCard shows values, dashes and taps', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          _host(
            entry.value,
            AppFactsCard(
              facts: [
                const AppFact('Customer', 'Asha'),
                const AppFact('Reason', null, key: Key('reason')),
                AppFact('Invoice', 'INV-1', onTap: () => tapped = true),
              ],
            ),
          ),
        );
        expect(find.text('Asha'), findsOneWidget);
        expect(find.text('—'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right), findsOneWidget);
        await tester.tap(find.text('INV-1'));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('AppFormDialog saves, shows a message and cancels', (
        tester,
      ) async {
        var saved = 0;
        Object? result = 'unset';
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<Object?>(
                    context: context,
                    builder: (_) => AppFormDialog(
                      title: 'New unit',
                      saveKey: const Key('save'),
                      message: 'Name already used',
                      cancelResult: false,
                      onSave: () => saved++,
                      children: const [Text('field one'), Text('field two')],
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('New unit'), findsOneWidget);
        expect(find.text('Name already used'), findsOneWidget);
        await tester.tap(find.byKey(const Key('save')));
        expect(saved, 1);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(result, false);
      });

      testWidgets('AppFormDialog disables buttons while saving', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: AppFormDialog(
              title: 'Busy',
              saving: true,
              saveKey: const Key('save'),
              onSave: () {},
              children: const [Text('x')],
            ),
          ),
        );
        final save = tester.widget<AppButton>(find.byKey(const Key('save')));
        expect(save.onPressed, isNull);
      });

      testWidgets('SettingsGroup lays out tiles and a switch', (tester) async {
        var on = false;
        await tester.pumpWidget(
          _host(
            entry.value,
            StatefulBuilder(
              builder: (context, setState) => SettingsGroup(
                title: 'Business',
                children: [
                  SettingsTile(
                    icon: Icons.storefront_outlined,
                    title: 'Business profile',
                    subtitle: 'Acme',
                    onTap: () {},
                  ),
                  SettingsSwitchTile(
                    key: const Key('sw'),
                    icon: Icons.verified_outlined,
                    title: 'Require approval',
                    value: on,
                    onChanged: (v) => setState(() => on = v),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(find.text('Business'), findsOneWidget);
        expect(find.text('Acme'), findsOneWidget);
        await tester.tap(find.byKey(const Key('sw')));
        await tester.pump();
        expect(on, isTrue);
      });

      testWidgets('AppDropdown shows helper and error text', (tester) async {
        await tester.pumpWidget(
          _host(
            entry.value,
            AppDropdown<int>(
              label: 'Decimals',
              helper: 'Precision',
              errorText: 'Pick one',
              value: 1,
              items: const [AppDropdownItem(value: 1, label: '1')],
              onChanged: (_) {},
            ),
          ),
        );
        expect(find.text('Pick one'), findsOneWidget);
      });
    });
  }
}
