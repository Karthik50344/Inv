import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/app.dart';
import 'package:inventrix/core/formatters/display_formats.dart';
import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/settings/domain/entities/money_lock.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/pages/business_profile_page.dart';
import 'package:inventrix/features/settings/presentation/pages/numbering_page.dart';
import 'package:inventrix/features/settings/presentation/pages/regional_settings_page.dart';
import 'package:inventrix/features/settings/presentation/pages/settings_page.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import '../../support/settings_fakes.dart';

/// Widget tests of the settings screens on fake repositories.
void main() {
  late SettingsFixture f;
  late SettingsCubit cubit;

  setUp(() {
    f = SettingsFixture();
    cubit = SettingsCubit(
      preferences: f.preferences,
      business: f.business,
      currencies: f.currencies,
      settings: f.settings,
      numbering: f.numbering,
      logos: f.logos,
      saveBusinessProfile: f.saveBusiness,
      changeCurrency: f.changeCurrency,
      updatePreferences: f.updatePreferences,
      saveNumbering: f.saveNumbering,
      setNextDocumentNumber: f.setNextNumber,
    );
  });

  tearDown(() async {
    await cubit.close();
    DisplayFormats.reset();
  });

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await cubit.load();
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: page),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('settings home shows the sections and saves a toggle', (
    tester,
  ) async {
    await pump(tester, const SettingsPage());
    expect(find.text('Business profile'), findsOneWidget);
    expect(find.text('Tax rates'), findsOneWidget);
    expect(find.text('Next invoice: INV-000001'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings_sales_approval')));
    await tester.pumpAndSettle();
    expect(f.preferences.value.salesApprovalRequired, isTrue);
    expect(f.audit.entries.single.entityId, 'sales_approval');
  });

  testWidgets('business profile shows validation errors', (tester) async {
    await pump(tester, const BusinessProfilePage());
    await tester.tap(find.byKey(const Key('business_save')));
    await tester.pumpAndSettle();
    expect(find.text('Business name is required.'), findsOneWidget);
    expect(f.business.profile, isNull);
  });

  testWidgets('numbering page shows previews and reports a bad prefix', (
    tester,
  ) async {
    await pump(tester, const NumberingPage());
    expect(find.text('Next: INV-000001'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('prefix_expense')), 'EXP9');
    await tester.tap(find.byKey(const Key('numbering_save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('must not end with a digit'), findsOneWidget);
  });

  testWidgets('currency is read-only while locked', (tester) async {
    f.currencies.lock = const MoneyLock(pricedProducts: 2);
    await pump(tester, const RegionalSettingsPage());
    expect(find.byKey(const Key('currency_locked')), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.byKey(const Key('currency_save')),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('changing the number style redraws existing screens', (
    tester,
  ) async {
    await pump(tester, const RegionalSettingsPage());
    expect(find.textContaining('12,34,567.89'), findsOneWidget);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: FormatRefresher(
            settings: cubit,
            child: Builder(
              builder: (_) => Text(
                const MoneyFormatter().format(
                  Money.fromMinor(
                    123456789,
                    currencyCode: 'INR',
                    decimalPlaces: 2,
                  ),
                  withSymbol: false,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('12,34,567.89'), findsOneWidget);
    await cubit.setNumberStyle(NumberStyle.european);
    await tester.pump();
    expect(find.text('1.234.567,89'), findsOneWidget);
  });
}
