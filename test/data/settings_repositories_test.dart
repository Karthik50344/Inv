import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/settings/data/repositories/drift_business_profile_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_currency_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_numbering_repository.dart';
import 'package:inventrix/features/settings/data/repositories/drift_preferences_repository.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/features/settings/domain/entities/numbering_settings.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/shared/data/drift_document_sequence_repository.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';

import '../support/fakes.dart';
import 'data_test_support.dart';

void main() {
  late DataHarness h;
  late DriftPreferencesRepository preferences;
  late DriftBusinessProfileRepository business;
  late DriftCurrencyRepository currency;
  late DriftNumberingRepository numbering;
  late DriftDocumentSequenceRepository sequences;

  setUp(() async {
    h = DataHarness();
    await h.db.initialize();
    preferences = DriftPreferencesRepository(h.db);
    business = DriftBusinessProfileRepository(
      h.db,
      SequentialIds(),
      FakeClock(),
    );
    currency = DriftCurrencyRepository(h.db);
    numbering = DriftNumberingRepository(h.db);
    sequences = DriftDocumentSequenceRepository(h.db);
  });

  tearDown(() => h.close());

  group('preferences', () {
    test('a fresh database yields the defaults', () async {
      expect((await preferences.load()).valueOrNull, const AppPreferences());
    });

    test('round-trips every field and clears optional ids', () async {
      const saved = AppPreferences(
        theme: ThemePreference.dark,
        dateStyle: DateStyle.yearMonthDay,
        numberStyle: NumberStyle.european,
        purchaseApprovalRequired: true,
        salesApprovalRequired: true,
        defaultPaymentMethodId: 'pm1',
        defaultTaxRateId: 'tx1',
        defaultPriceIncludesTax: true,
        backupReminderDays: 14,
      );
      await preferences.save(saved);
      expect((await preferences.load()).valueOrNull, saved);

      await preferences.save(
        saved.copyWith(
          clearDefaultPaymentMethod: true,
          clearDefaultTaxRate: true,
        ),
      );
      final again = (await preferences.load()).valueOrNull!;
      expect(again.defaultPaymentMethodId, isNull);
      expect(again.defaultTaxRateId, isNull);
    });

    test('unreadable stored values fall back to defaults', () async {
      await h.db.customStatement(
        "INSERT INTO app_settings (key, value, updated_at) VALUES "
        "('theme_mode','neon',0),('date_style','x',0),"
        "('backup_reminder_days','9',0)",
      );
      final loaded = (await preferences.load()).valueOrNull!;
      expect(loaded.theme, ThemePreference.system);
      expect(loaded.dateStyle, DateStyle.longMonth);
      expect(loaded.backupReminderDays, 0);
    });

    test(
      'keeps the approval keys the older settings repository reads',
      () async {
        await preferences.save(
          const AppPreferences(salesApprovalRequired: true),
        );
        expect(
          (await h.settings.isSalesApprovalRequired()).valueOrNull,
          isTrue,
        );
      },
    );
  });

  group('business profile', () {
    test('none until saved; insert then update the single row', () async {
      expect((await business.find()).valueOrNull, isNull);
      await business.save(const BusinessProfile(name: 'Acme', phone: '123'));
      await business.save(
        const BusinessProfile(
          name: 'Acme Ltd',
          logoPath: 'product_images/logo_a.png',
        ),
      );
      final found = (await business.find()).valueOrNull!;
      expect(found.name, 'Acme Ltd');
      expect(found.phone, isNull);
      expect(found.logoPath, 'product_images/logo_a.png');
      final rows = await h.db.select(h.db.businessProfiles).get();
      expect(rows, hasLength(1));
    });

    test('the settings repository reads what was saved', () async {
      await business.save(const BusinessProfile(name: 'Acme'));
      expect((await h.settings.getBusinessProfile()).valueOrNull?.name, 'Acme');
    });
  });

  group('currency', () {
    test('saves and is read by the settings repository', () async {
      await currency.save(
        const CurrencyConfig(currencyCode: 'KWD', decimalPlaces: 3),
      );
      final config = (await h.settings.getCurrencyConfig()).valueOrNull!;
      expect(config.currencyCode, 'KWD');
      expect(config.decimalPlaces, 3);
    });

    test('money lock counts only amounts without their own currency', () async {
      expect((await currency.moneyLock()).valueOrNull!.isLocked, isFalse);
      await h.units.create(unit());
      await h.products.create(product(id: 'priced'));
      final lock = (await currency.moneyLock()).valueOrNull!;
      expect(lock.isLocked, isTrue);
      expect(lock.pricedProducts, 1);
      await h.db.customStatement(
        'UPDATE products SET purchase_price_minor = 0, selling_price_minor = 0',
      );
      expect(
        (await currency.moneyLock()).valueOrNull!.isLocked,
        isFalse,
        reason: 'prices of zero do not depend on the currency',
      );
    });
  });

  group('numbering', () {
    test('defaults, then saved prefixes and padding', () async {
      final fresh = (await numbering.load()).valueOrNull!;
      expect(fresh.preview(DocumentKind.salesInvoice), 'INV-000001');

      await numbering.save(
        const NumberingSettings(
          prefixes: {DocumentKind.salesInvoice: 'SALE-'},
          padding: 4,
        ),
      );
      final loaded = (await numbering.load()).valueOrNull!;
      expect(loaded.preview(DocumentKind.salesInvoice), 'SALE-0001');
      expect(loaded.prefixOf(DocumentKind.purchaseInvoice), 'PUR-');
    });

    test('nextNumber uses the settings at posting time', () async {
      expect(
        (await sequences.nextNumber(DocumentKind.salesInvoice)).valueOrNull,
        'INV-000001',
      );
      await numbering.save(
        const NumberingSettings(
          prefixes: {DocumentKind.salesInvoice: 'SALE-'},
          padding: 4,
        ),
      );
      expect(
        (await sequences.nextNumber(DocumentKind.salesInvoice)).valueOrNull,
        'SALE-0002',
      );
      expect(
        (await sequences.nextNumber(DocumentKind.expense)).valueOrNull,
        'EXP-000001',
      );
    });

    test('a corrupt stored prefix falls back to the default', () async {
      await h.db.customStatement(
        "INSERT INTO app_settings (key, value, updated_at) VALUES "
        "('numbering.prefix.sales_invoice','BAD 1',0),"
        "('numbering.padding','99',0)",
      );
      expect(
        (await sequences.nextNumber(DocumentKind.salesInvoice)).valueOrNull,
        'INV-000001',
      );
    });

    test('advanceTo moves forward, never back', () async {
      await sequences.nextNumber(DocumentKind.salesInvoice);
      expect(
        (await numbering.advanceTo(DocumentKind.salesInvoice, 1500)).isSuccess,
        isTrue,
      );
      expect(
        (await sequences.nextNumber(DocumentKind.salesInvoice)).valueOrNull,
        'INV-001500',
      );
      final back = await numbering.advanceTo(DocumentKind.salesInvoice, 3);
      expect(back.failureOrNull, isA<ValidationFailure>());
      expect(
        (await numbering.load()).valueOrNull!.lastValueOf(
          DocumentKind.salesInvoice,
        ),
        1500,
      );
    });
  });

  group('tax rates', () {
    TaxRate rate(String id, String name, {int bp = 1800, DateTime? archived}) =>
        TaxRate(
          id: id,
          name: name,
          rateBp: bp,
          isExempt: false,
          createdAt: t0,
          updatedAt: t0,
          archivedAt: archived,
        );

    test('update replaces the row; unknown id is not found', () async {
      await h.taxRates.create(rate('t1', 'GST'));
      await h.taxRates.update(rate('t1', 'GST std', bp: 2000));
      final loaded = (await h.taxRates.getById('t1')).valueOrNull!;
      expect(loaded.name, 'GST std');
      expect(loaded.rateBp, 2000);
      expect(
        (await h.taxRates.update(rate('nope', 'x'))).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('nameExists can ignore the rate being renamed', () async {
      await h.taxRates.create(rate('t1', 'GST'));
      expect((await h.taxRates.nameExists('gst')).valueOrNull, isTrue);
      expect(
        (await h.taxRates.nameExists('gst', excludingId: 't1')).valueOrNull,
        isFalse,
      );
    });

    test('isInUse sees products', () async {
      await h.taxRates.create(rate('t1', 'GST'));
      expect((await h.taxRates.isInUse('t1')).valueOrNull, isFalse);
      await h.units.create(unit());
      await h.products.create(product(id: 'p9'));
      await h.db.customStatement("UPDATE products SET tax_rate_id = 't1'");
      expect((await h.taxRates.isInUse('t1')).valueOrNull, isTrue);
    });
  });
}
