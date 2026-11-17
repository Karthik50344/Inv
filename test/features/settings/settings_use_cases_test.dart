import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile_input.dart';
import 'package:inventrix/features/settings/domain/entities/money_lock.dart';
import 'package:inventrix/features/settings/domain/entities/numbering_settings.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';

import '../../support/settings_fakes.dart';

TaxRate rate(String id, String name, int bp, {DateTime? archivedAt}) => TaxRate(
  id: id,
  name: name,
  rateBp: bp,
  isExempt: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  archivedAt: archivedAt,
);

void main() {
  late SettingsFixture f;

  setUp(() => f = SettingsFixture());

  group('SaveBusinessProfile', () {
    test('saves trimmed text, blanks become null, and audits', () async {
      final result = await f.saveBusiness(
        const BusinessProfileInput(
          name: '  Acme Traders ',
          address: '1 Market Road',
          phone: '  ',
          email: 'owner@acme.test',
          taxId: '',
        ),
      );
      expect(result.valueOrNull?.name, 'Acme Traders');
      expect(f.business.profile?.phone, isNull);
      expect(f.business.profile?.email, 'owner@acme.test');
      expect(f.audit.entries.single.entityId, 'business_profile');
      expect(f.audit.entries.single.summary.contains('Acme'), isFalse);
    });

    test('reports field errors and saves nothing', () async {
      final result = await f.saveBusiness(
        const BusinessProfileInput(name: ' ', email: 'nope', phone: 'abc'),
      );
      final failure = result.failureOrNull as ValidationFailure;
      expect(failure.fieldErrors.keys, containsAll(['name', 'email', 'phone']));
      expect(f.business.profile, isNull);
      expect(f.audit.entries, isEmpty);
    });

    test('deletes the replaced logo only after a successful save', () async {
      f.business.profile = const BusinessProfile(
        name: 'Acme',
        logoPath: 'product_images/logo_old.png',
      );
      await f.saveBusiness(
        const BusinessProfileInput(
          name: 'Acme',
          logoPath: 'product_images/logo_new.png',
        ),
      );
      expect(f.logos.deleted, ['product_images/logo_old.png']);

      f.logos.deleted.clear();
      await f.saveBusiness(const BusinessProfileInput(name: ''));
      expect(f.logos.deleted, isEmpty);
    });

    test('keeping the same logo deletes nothing', () async {
      f.business.profile = const BusinessProfile(
        name: 'Acme',
        logoPath: 'product_images/logo_old.png',
      );
      await f.saveBusiness(
        const BusinessProfileInput(
          name: 'Acme 2',
          logoPath: 'product_images/logo_old.png',
        ),
      );
      expect(f.logos.deleted, isEmpty);
    });

    test('a failed audit rolls the profile back', () async {
      f.audit.recordFailure = const DatabaseFailure('x');
      final result = await f.saveBusiness(
        const BusinessProfileInput(name: 'Acme'),
      );
      expect(result.isFailure, isTrue);
      expect(f.business.profile, isNull);
    });
  });

  group('ChangeCurrency', () {
    test('changes the currency when nothing depends on it', () async {
      final result = await f.changeCurrency(code: ' usd ', decimalPlaces: 3);
      expect(
        result.valueOrNull,
        const CurrencyConfig(currencyCode: 'USD', decimalPlaces: 3),
      );
      expect(f.settings.config.currencyCode, 'USD');
      expect(
        f.audit.entries.single.summary,
        'Currency changed from INR (2 decimals) to USD (3 decimals).',
      );
    });

    test('is refused while prices, balances or stock costs exist', () async {
      f.currencies.lock = const MoneyLock(pricedProducts: 2, stockRecords: 5);
      final result = await f.changeCurrency(code: 'USD', decimalPlaces: 2);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(
        result.failureOrNull!.userMessage,
        contains('2 products have a price'),
      );
      expect(f.settings.config.currencyCode, 'INR');
      expect(f.audit.entries, isEmpty);
    });

    test(
      'saving the same currency is a harmless no-op even when locked',
      () async {
        f.currencies.lock = const MoneyLock(pricedProducts: 1);
        final result = await f.changeCurrency(code: 'inr', decimalPlaces: 2);
        expect(result.isSuccess, isTrue);
        expect(f.audit.entries, isEmpty);
      },
    );

    test('posted invoices lock the currency and are named in the reason',
        () async {
      f.currencies.lock = const MoneyLock(postedInvoices: 3);
      final result = await f.changeCurrency(code: 'USD', decimalPlaces: 2);
      expect(result.failureOrNull!.userMessage, contains('3 invoices are posted'));
    });

    test('validates the code and decimals', () async {
      final bad = await f.changeCurrency(code: 'US', decimalPlaces: 5);
      final failure = bad.failureOrNull as ValidationFailure;
      expect(failure.fieldErrors.keys, containsAll(['code', 'decimalPlaces']));
      expect(
        (await f.changeCurrency(code: '12A', decimalPlaces: 2)).isFailure,
        isTrue,
      );
    });

    test('decimals alone are locked too: 12.50 would become 1250', () async {
      f.currencies.lock = const MoneyLock(openingBalances: 1);
      final result = await f.changeCurrency(code: 'INR', decimalPlaces: 0);
      expect(result.isFailure, isTrue);
    });
  });

  group('UpdatePreferences', () {
    test('applies a change and audits approval toggles only', () async {
      final theme = await f.updatePreferences(
        (p) => p.copyWith(theme: ThemePreference.dark),
      );
      expect(theme.valueOrNull?.theme, ThemePreference.dark);
      expect(f.audit.entries, isEmpty);

      await f.updatePreferences((p) => p.copyWith(salesApprovalRequired: true));
      expect(f.audit.entries.single.entityId, 'sales_approval');
      expect(f.audit.entries.single.action, 'enabled');

      await f.updatePreferences(
        (p) => p.copyWith(salesApprovalRequired: false),
      );
      expect(f.audit.entries.last.action, 'disabled');
    });

    test('an unchanged value writes and audits nothing', () async {
      await f.updatePreferences(
        (p) => p.copyWith(salesApprovalRequired: false),
      );
      expect(f.audit.entries, isEmpty);
    });

    test('rejects a reminder interval that is not offered', () async {
      final result = await f.updatePreferences(
        (p) => p.copyWith(backupReminderDays: 10),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(f.preferences.value.backupReminderDays, 0);
      final ok = await f.updatePreferences(
        (p) => p.copyWith(backupReminderDays: 14),
      );
      expect(ok.valueOrNull?.backupReminderDays, 14);
    });
  });

  group('SaveNumbering', () {
    test(
      'saves prefixes and padding, keeps counters, audits changes',
      () async {
        f.numbering.value = const NumberingSettings(
          lastValues: {DocumentKind.salesInvoice: 41},
        );
        final result = await f.saveNumbering(
          prefixes: {
            DocumentKind.salesInvoice: 'SALE-',
            DocumentKind.payment: 'RCPT/',
          },
          padding: 4,
        );
        final saved = result.valueOrNull!;
        expect(saved.prefixOf(DocumentKind.salesInvoice), 'SALE-');
        expect(saved.prefixOf(DocumentKind.purchaseInvoice), 'PUR-');
        expect(saved.padding, 4);
        expect(saved.lastValueOf(DocumentKind.salesInvoice), 41);
        expect(saved.preview(DocumentKind.salesInvoice), 'SALE-0042');
        expect(
          f.audit.entries.single.summary,
          contains('Sales invoices: INV- -> SALE-'),
        );
      },
    );

    test('rejects bad and duplicate prefixes with per-field errors', () async {
      final result = await f.saveNumbering(
        prefixes: {
          DocumentKind.salesInvoice: 'X-',
          DocumentKind.purchaseInvoice: 'x-',
          DocumentKind.expense: 'EXP1',
        },
        padding: 2,
      );
      final errors = (result.failureOrNull as ValidationFailure).fieldErrors;
      expect(
        errors.keys,
        containsAll(['prefix.purchase_invoice', 'prefix.expense', 'padding']),
      );
      expect(f.numbering.value.prefixes, isEmpty);
    });

    test('saving unchanged settings audits nothing', () async {
      await f.saveNumbering(prefixes: const {}, padding: 6);
      expect(f.audit.entries, isEmpty);
    });
  });

  group('SetNextDocumentNumber', () {
    test('moves the counter forward only', () async {
      final ok = await f.setNextNumber(DocumentKind.salesInvoice, '1500');
      expect(ok.valueOrNull?.nextValueOf(DocumentKind.salesInvoice), 1500);
      expect(f.numbering.value.lastValueOf(DocumentKind.salesInvoice), 1499);

      final back = await f.setNextNumber(DocumentKind.salesInvoice, '1500');
      expect(back.isSuccess, isTrue, reason: 'same value is a no-op');

      final lower = await f.setNextNumber(DocumentKind.salesInvoice, '10');
      final failure = lower.failureOrNull as ValidationFailure;
      expect(failure.userMessage, contains('Enter 1500 or higher'));
      expect(f.numbering.value.lastValueOf(DocumentKind.salesInvoice), 1499);
    });

    test('rejects text, zero and absurd numbers', () async {
      for (final bad in ['', 'abc', '0', '-3', '1.5', '1000000000']) {
        expect(
          (await f.setNextNumber(DocumentKind.expense, bad)).isFailure,
          isTrue,
          reason: bad,
        );
      }
    });
  });

  group('tax rates', () {
    setUp(() {
      f.taxRates.items['t1'] = rate('t1', 'GST 18', 1800);
      f.taxRates.items['t2'] = rate('t2', 'GST 5', 500);
    });

    test('rename works even when the rate is in use', () async {
      f.taxRates.inUse.add('t1');
      final result = await f.updateTaxRate(
        id: 't1',
        name: 'GST standard',
        ratePercent: '18',
        isExempt: false,
      );
      expect(result.valueOrNull?.name, 'GST standard');
      expect(f.audit.entries.single.entityType, 'tax_rate');
    });

    test(
      'the percentage is locked while products or expenses use it',
      () async {
        f.taxRates.inUse.add('t1');
        final result = await f.updateTaxRate(
          id: 't1',
          name: 'GST 18',
          ratePercent: '20',
          isExempt: false,
        );
        expect(result.failureOrNull!.userMessage, contains('archive'));
        expect(f.taxRates.items['t1']!.rateBp, 1800);
      },
    );

    test('the percentage can change while unused', () async {
      final result = await f.updateTaxRate(
        id: 't1',
        name: 'GST 20',
        ratePercent: '20',
        isExempt: false,
      );
      expect(result.valueOrNull?.rateBp, 2000);
    });

    test('a name used by another active rate is refused', () async {
      final result = await f.updateTaxRate(
        id: 't1',
        name: 'gst 5',
        ratePercent: '18',
        isExempt: false,
      );
      expect(
        (result.failureOrNull as ValidationFailure).fieldErrors['name'],
        isNotNull,
      );
    });

    test('keeping its own name is fine', () async {
      final result = await f.updateTaxRate(
        id: 't2',
        name: 'GST 5',
        ratePercent: '5',
        isExempt: false,
      );
      expect(result.isSuccess, isTrue);
      expect(f.audit.entries, isEmpty, reason: 'nothing changed');
    });

    test(
      'archiving the default clears the default; restore checks the name',
      () async {
        await f.setDefaultTax('t1');
        expect(f.preferences.value.defaultTaxRateId, 't1');
        await f.setTaxArchived('t1', archived: true);
        expect(f.taxRates.items['t1']!.isArchived, isTrue);
        expect(f.preferences.value.defaultTaxRateId, isNull);

        f.taxRates.items['t3'] = rate('t3', 'GST 18', 1800);
        final restore = await f.setTaxArchived('t1', archived: false);
        expect(restore.isFailure, isTrue, reason: 'name clashes with t3');
        expect(f.taxRates.items['t1']!.isArchived, isTrue);
      },
    );

    test('an archived rate cannot become the default', () async {
      await f.setTaxArchived('t2', archived: true);
      expect((await f.setDefaultTax('t2')).isFailure, isTrue);
      expect(f.preferences.value.defaultTaxRateId, isNull);
      expect((await f.setDefaultTax(null)).isSuccess, isTrue);
    });
  });
}
