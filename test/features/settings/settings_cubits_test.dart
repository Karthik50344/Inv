import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/formatters/display_formats.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile_input.dart';
import 'package:inventrix/features/settings/domain/entities/money_lock.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/usecases/create_tax_rate.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/tax_rates_cubit.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/settings_fakes.dart';

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

  group('SettingsCubit', () {
    test('starts initial, then loads everything', () async {
      expect(cubit.state.status, ViewStatus.initial);
      f.business.profile = const BusinessProfile(name: 'Acme');
      f.preferences.value = f.preferences.value.copyWith(
        numberStyle: NumberStyle.european,
        dateStyle: DateStyle.yearMonthDay,
      );
      f.currencies.lock = const MoneyLock(pricedProducts: 1);
      await cubit.load();
      expect(cubit.state.status, ViewStatus.loaded);
      expect(cubit.state.business?.name, 'Acme');
      expect(cubit.state.currency.currencyCode, 'INR');
      expect(cubit.state.moneyLock.isLocked, isTrue);
      expect(cubit.state.preferences.numberStyle, NumberStyle.european);
    });

    test('loading applies the saved formats app-wide', () async {
      f.preferences.value = f.preferences.value.copyWith(
        numberStyle: NumberStyle.international,
        dateStyle: DateStyle.monthDayYear,
      );
      await cubit.load();
      expect(DisplayFormats.numberStyle, NumberStyle.international);
      expect(DisplayFormats.dateStyle, DateStyle.monthDayYear);
    });

    test('a failed load shows the failure', () async {
      f.preferences.failure = const DatabaseFailure('disk');
      await cubit.load();
      expect(cubit.state.status, ViewStatus.failure);
      expect(cubit.state.message, 'disk');
    });

    test('changing a format saves it and applies it immediately', () async {
      await cubit.load();
      await cubit.setNumberStyle(NumberStyle.spaced);
      await cubit.setDateStyle(DateStyle.dayMonthYear);
      expect(f.preferences.value.numberStyle, NumberStyle.spaced);
      expect(DisplayFormats.numberStyle, NumberStyle.spaced);
      expect(DisplayFormats.dateStyle, DateStyle.dayMonthYear);
      expect(cubit.state.preferences.numberStyle, NumberStyle.spaced);
    });

    test('theme and approvals persist', () async {
      await cubit.load();
      await cubit.setTheme(ThemePreference.dark);
      await cubit.setSalesApproval(required: true);
      await cubit.setPurchaseApproval(required: true);
      await cubit.setBackupReminderDays(30);
      final saved = f.preferences.value;
      expect(saved.theme, ThemePreference.dark);
      expect(saved.salesApprovalRequired, isTrue);
      expect(saved.purchaseApprovalRequired, isTrue);
      expect(saved.backupReminderDays, 30);
    });

    test('saveBusiness updates the state, or exposes field errors', () async {
      await cubit.load();
      expect(
        await cubit.saveBusiness(const BusinessProfileInput(name: 'Acme')),
        isTrue,
      );
      expect(cubit.state.business?.name, 'Acme');
      expect(cubit.state.message, 'Business profile saved.');

      expect(
        await cubit.saveBusiness(const BusinessProfileInput(name: '')),
        isFalse,
      );
      expect(cubit.state.fieldErrors['name'], isNotNull);
      expect(cubit.state.business?.name, 'Acme', reason: 'unchanged');
      expect(cubit.state.saving, isFalse);
    });

    test('the same message can be shown twice', () async {
      await cubit.load();
      await cubit.saveBusiness(const BusinessProfileInput(name: 'A'));
      final first = cubit.state.messageSerial;
      await cubit.saveBusiness(const BusinessProfileInput(name: 'B'));
      expect(cubit.state.messageSerial, first + 1);
    });

    test('currency change succeeds, or explains the lock', () async {
      await cubit.load();
      expect(await cubit.saveCurrency(code: 'USD', decimalPlaces: 2), isTrue);
      expect(cubit.state.currency.currencyCode, 'USD');

      f.currencies.lock = const MoneyLock(stockRecords: 3);
      expect(await cubit.saveCurrency(code: 'EUR', decimalPlaces: 2), isFalse);
      expect(cubit.state.currency.currencyCode, 'USD');
      expect(cubit.state.message, contains('cannot be changed'));
    });

    test('numbering and next number', () async {
      await cubit.load();
      expect(
        await cubit.saveNumbering(
          prefixes: {DocumentKind.salesInvoice: 'SALE-'},
          padding: 5,
        ),
        isTrue,
      );
      expect(
        cubit.state.numbering.preview(DocumentKind.salesInvoice),
        'SALE-00001',
      );
      expect(
        await cubit.setNextNumber(DocumentKind.salesInvoice, '250'),
        isTrue,
      );
      expect(
        cubit.state.numbering.preview(DocumentKind.salesInvoice),
        'SALE-00250',
      );
      expect(
        await cubit.setNextNumber(DocumentKind.salesInvoice, '5'),
        isFalse,
      );
      expect(cubit.state.fieldErrors['next.sales_invoice'], isNotNull);
    });

    test('storing a logo returns the stored path', () async {
      final result = await cubit.storeLogo('/tmp/logo.png');
      expect(result.valueOrNull, 'product_images/logo_stored.png');
    });
  });

  group('TaxRatesCubit', () {
    late TaxRatesCubit rates;

    setUp(() {
      rates = TaxRatesCubit(
        taxRates: f.taxRates,
        preferences: f.preferences,
        createTaxRate: CreateTaxRate(
          repository: f.taxRates,
          ids: f.ids,
          clock: f.clock,
        ),
        updateTaxRate: f.updateTaxRate,
        setArchived: f.setTaxArchived,
        setDefault: f.setDefaultTax,
        updatePreferences: f.updatePreferences,
      );
    });

    tearDown(() => rates.close());

    test('empty list is reported as empty', () async {
      await rates.load();
      expect(rates.state.status, ViewStatus.empty);
    });

    test('create, default, archive flow', () async {
      final created = await rates.create(
        name: 'GST 18',
        ratePercent: '18',
        isExempt: false,
      );
      final id = created.valueOrNull!.id;
      expect(rates.state.status, ViewStatus.loaded);
      expect(rates.state.rates.single.name, 'GST 18');

      await rates.setDefault(id);
      expect(rates.state.defaultRateId, id);

      await rates.setArchived(id, archived: true);
      expect(rates.state.rates.single.isArchived, isTrue);
      expect(rates.state.defaultRateId, isNull);
    });

    test('create returns field errors to the dialog', () async {
      final result = await rates.create(
        name: '',
        ratePercent: 'x',
        isExempt: false,
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('update refuses a change to a rate in use and shows why', () async {
      f.taxRates.items['t'] = TaxRate(
        id: 't',
        name: 'GST',
        rateBp: 1800,
        isExempt: false,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      f.taxRates.inUse.add('t');
      final result = await rates.update(
        id: 't',
        name: 'GST',
        ratePercent: '20',
        isExempt: false,
      );
      expect(result.isFailure, isTrue);
    });

    test('default price-includes-tax is stored', () async {
      await rates.load();
      await rates.setDefaultPriceIncludesTax(value: true);
      expect(f.preferences.value.defaultPriceIncludesTax, isTrue);
      expect(rates.state.defaultPriceIncludesTax, isTrue);
    });
  });
}
