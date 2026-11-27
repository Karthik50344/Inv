import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/presentation/pages/tax_settings_page.dart';
import 'package:inventrix/features/taxation/presentation/support/tax_labels.dart';
import 'package:inventrix/features/taxation/presentation/widgets/tax_forms.dart';

import '../tax_test_fixtures.dart';

void main() {
  group('TaxLabels', () {
    test('basis points read as percentages', () {
      expect(TaxLabels.percent(900), '9%');
      expect(TaxLabels.percent(950), '9.5%');
      expect(TaxLabels.percent(1), '0.01%');
      expect(TaxLabels.percent(0), '0%');
      expect(TaxLabels.percent(100000), '1000%');
      expect(TaxLabels.percent(1250), '12.5%');
    });

    test('typed percentages become basis points', () {
      expect(TaxLabels.parsePercent('9'), 900);
      expect(TaxLabels.parsePercent('9.5'), 950);
      expect(TaxLabels.parsePercent('9,5'), 950);
      expect(TaxLabels.parsePercent(' 18 % '), 1800);
      expect(TaxLabels.parsePercent('0.01'), 1);
      expect(TaxLabels.parsePercent('1000'), 100000);
    });

    test('bad percentages are refused', () {
      for (final bad in ['', 'abc', '1000.01', '1001', '-5', '9.999', '1e3']) {
        expect(TaxLabels.parsePercent(bad), isNull, reason: bad);
      }
    });

    test('amounts are parsed with the currency decimals', () {
      expect(TaxLabels.parseMinor('12.5', 2), 1250);
      expect(TaxLabels.parseMinor('12', 2), 1200);
      expect(TaxLabels.parseMinor('12,50', 2), 1250);
      expect(TaxLabels.parseMinor('12', 0), 12);
      expect(TaxLabels.parseMinor('12.5', 0), isNull);
      expect(TaxLabels.parseMinor('1.234', 2), isNull);
      expect(TaxLabels.parseMinor('1.234', 3), 1234);
      expect(TaxLabels.parseMinor('x', 2), isNull);
    });

    test('minor units read back as text', () {
      expect(TaxLabels.minorText(1250, 2), '12.50');
      expect(TaxLabels.minorText(5, 2), '0.05');
      expect(TaxLabels.minorText(7, 0), '7');
      expect(TaxLabels.minorText(1234, 3), '1.234');
    });

    test('rule lines and places are described', () {
      final c = config(
        rules: [rule('r1'), rule('r2', method: TaxCalculationMethod.fixed), rule('r3')],
        components: [
          component('a', 'r1', name: 'CGST', rate: 900),
          component('b', 'r1', name: 'SGST', rate: 950, order: 2),
          component('f', 'r2', name: 'Levy', fixed: 500),
        ],
        jurisdictions: const [
          TaxJurisdiction(id: 'ka', regimeId: 'r1', countryCode: 'IN', regionCode: 'KA', regionName: 'Karnataka', jurisdictionType: JurisdictionType.state),
        ],
      );
      expect(TaxLabels.ruleLines(c, c.rules[0]), 'CGST 9% + SGST 9.5%');
      expect(TaxLabels.ruleLines(c, c.rules[1]), 'Levy 5.00 per unit');
      expect(TaxLabels.ruleLines(c, c.rules[2]), 'No tax lines yet');
      expect(TaxLabels.place(c, null), 'Everywhere');
      expect(TaxLabels.place(c, 'ka'), 'Karnataka');
      expect(TaxLabels.place(c, 'gone'), 'Unknown place');
    });

    test('every treatment, relation and method has a plain description', () {
      for (final t in TaxTreatment.values) {
        expect(TaxLabels.treatmentHelp(t), isNotEmpty);
      }
      for (final r in SupplyRelation.values) {
        expect(TaxLabels.relation(r), isNotEmpty);
      }
      expect(TaxLabels.transactionType(null), 'Any transaction');
    });
  });

  group('setup warnings', () {
    const prefs = TaxPreferences(countryCode: 'IN');

    test('nothing set up asks to start with a tax system', () {
      final w = taxSetupWarnings(TaxConfiguration(), prefs);
      expect(w.first, contains('No tax system'));
    });

    test('a complete setup has no warnings', () {
      final c = config(
        rules: [rule('r1')],
        components: [component('c', 'r1', rate: 100)],
      );
      expect(taxSetupWarnings(c, prefs), isEmpty);
    });

    test('a charging category without a rule is reported, an exempt one is not', () {
      final c = config(categories: [category(kCategory), category('ex', treatment: TaxTreatment.exempt)]);
      final w = taxSetupWarnings(c, prefs);
      expect(w.where((m) => m.contains('Category c1')), hasLength(1));
      expect(w.any((m) => m.contains('Category ex')), isFalse);
    });

    test('a rule without tax lines is reported', () {
      final c = config(rules: [rule('r1')]);
      expect(taxSetupWarnings(c, prefs).any((m) => m.contains('no tax lines')), isTrue);
    });

    test('a missing country is reported', () {
      final c = config(rules: [rule('r1')], components: [component('c', 'r1', rate: 100)]);
      expect(taxSetupWarnings(c, const TaxPreferences()).single, contains('country'));
    });
  });

  group('forms', () {
    Future<void> open(WidgetTester tester, Widget form, {ThemeData? theme}) async {
      tester.view
        ..physicalSize = const Size(420, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => showTaxFormSheet(context, form), child: const Text('open')))),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    final percentRule = rule('r1');
    final fixedRule = rule('rf', method: TaxCalculationMethod.fixed);

    for (final theme in {'light': AppTheme.light(), 'dark': AppTheme.dark()}.entries) {
      testWidgets('a percentage line is saved as basis points, in ${theme.key}', (tester) async {
        TaxComponent? saved;
        await open(
          tester,
          TaxComponentForm(
            id: 'new',
            rule: percentRule,
            nextOrder: 2,
            currencyDecimals: 2,
            onSave: (c) async {
              saved = c;
              return null;
            },
          ),
          theme: theme.value,
        );
        await tester.enterText(find.widgetWithText(TextField, 'Name on invoices'), 'CGST');
        await tester.enterText(find.widgetWithText(TextField, 'Rate (%)'), '9.5');
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(saved!.name, 'CGST');
        expect(saved!.rateBasisPoints, 950);
        expect(saved!.calculationOrder, 2);
        expect(saved!.taxRuleId, 'r1');
        expect(saved!.fixedAmountMinor, isNull);
        expect(find.text('Add a tax line'), findsNothing); // sheet closed
      });
    }

    testWidgets('a bad rate is explained and nothing is saved', (tester) async {
      var calls = 0;
      await open(
        tester,
        TaxComponentForm(id: 'new', rule: percentRule, nextOrder: 1, currencyDecimals: 2, onSave: (_) async {
          calls++;
          return null;
        }),
      );
      await tester.enterText(find.widgetWithText(TextField, 'Name on invoices'), 'CGST');
      await tester.enterText(find.widgetWithText(TextField, 'Rate (%)'), '1200');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('from 0 to 1000'), findsOneWidget);
      expect(calls, 0);
    });

    testWidgets('a fixed rule asks for an amount and uses the currency decimals', (tester) async {
      TaxComponent? saved;
      await open(
        tester,
        TaxComponentForm(id: 'new', rule: fixedRule, nextOrder: 1, currencyDecimals: 3, onSave: (c) async {
          saved = c;
          return null;
        }),
      );
      expect(find.text('Rate (%)'), findsNothing);
      await tester.enterText(find.widgetWithText(TextField, 'Name on invoices'), 'Levy');
      await tester.enterText(find.widgetWithText(TextField, 'Amount per unit'), '1.234');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved!.fixedAmountMinor, 1234);
      expect(saved!.rateBasisPoints, 0);
      expect(saved!.isCompound, isFalse);
    });

    testWidgets('field errors from the save are shown and the sheet stays open', (tester) async {
      await open(
        tester,
        TaxCategoryForm(
          id: 'new',
          onSave: (_) async => const ValidationFailure('x', fieldErrors: {'code': 'Another category already uses this code.'}),
        ),
      );
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Standard');
      await tester.enterText(find.widgetWithText(TextField, 'Short code'), 'STD');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Another category already uses this code.'), findsOneWidget);
      expect(find.text('Add a tax category'), findsOneWidget);
    });

    testWidgets('a failure without field errors is shown as a message', (tester) async {
      await open(tester, TaxCategoryForm(id: 'new', onSave: (_) async => const DatabaseFailure('The data is locked.')));
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'A');
      await tester.enterText(find.widgetWithText(TextField, 'Short code'), 'A');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('The data is locked.'), findsOneWidget);
    });

    testWidgets('editing a rule shows its profile and category as fixed', (tester) async {
      final c = config(rules: [percentRule]);
      await open(tester, TaxRuleForm(id: 'x', configuration: c, existing: percentRule, onSave: (_) async => null));
      expect(find.text('Edit tax rule'), findsOneWidget);
      final profile = tester.widget<DropdownButtonFormField<String?>>(find.byType(DropdownButtonFormField<String?>).first);
      expect(profile.onChanged, isNull);
    });
  });
}
