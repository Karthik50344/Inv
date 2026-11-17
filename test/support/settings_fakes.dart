import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/features/settings/domain/entities/money_lock.dart';
import 'package:inventrix/features/settings/domain/entities/numbering_settings.dart';
import 'package:inventrix/features/settings/domain/repositories/business_profile_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/currency_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/logo_storage.dart';
import 'package:inventrix/features/settings/domain/repositories/numbering_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/features/settings/domain/usecases/change_currency.dart';
import 'package:inventrix/features/settings/domain/usecases/manage_tax_rates.dart';
import 'package:inventrix/features/settings/domain/usecases/save_business_profile.dart';
import 'package:inventrix/features/settings/domain/usecases/save_numbering.dart';
import 'package:inventrix/features/settings/domain/usecases/update_preferences.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

import 'fakes.dart';
import 'inventory_fakes.dart';

class FakePreferencesRepository implements PreferencesRepository, Rollbackable {
  AppPreferences value = const AppPreferences();
  Failure? failure;

  @override
  Future<Result<AppPreferences>> load() async =>
      failure == null ? Result.success(value) : Result.failure(failure!);

  @override
  Future<Result<void>> save(AppPreferences preferences) async {
    value = preferences;
    return const Result.success(null);
  }

  @override
  Object snapshot() => value;

  @override
  void restore(Object snapshot) => value = snapshot as AppPreferences;
}

class FakeBusinessProfileRepository
    implements BusinessProfileRepository, Rollbackable {
  BusinessProfile? profile;

  @override
  Future<Result<BusinessProfile?>> find() async => Result.success(profile);

  @override
  Future<Result<void>> save(BusinessProfile value) async {
    profile = value;
    return const Result.success(null);
  }

  @override
  Object snapshot() => profile ?? 'none';

  @override
  void restore(Object snapshot) =>
      profile = snapshot is BusinessProfile ? snapshot : null;
}

class FakeCurrencyRepository implements CurrencyRepository, Rollbackable {
  FakeCurrencyRepository(this.settings);

  final FakeSettingsRepository settings;
  MoneyLock lock = MoneyLock.none;

  @override
  Future<Result<MoneyLock>> moneyLock() async => Result.success(lock);

  @override
  Future<Result<void>> save(CurrencyConfig config) async {
    settings.config = config;
    return const Result.success(null);
  }

  @override
  Object snapshot() => settings.config;

  @override
  void restore(Object snapshot) => settings.config = snapshot as CurrencyConfig;
}

class FakeNumberingRepository implements NumberingRepository, Rollbackable {
  NumberingSettings value = const NumberingSettings();

  @override
  Future<Result<NumberingSettings>> load() async => Result.success(value);

  @override
  Future<Result<void>> save(NumberingSettings settings) async {
    value = NumberingSettings(
      prefixes: settings.prefixes,
      padding: settings.padding,
      lastValues: value.lastValues,
    );
    return const Result.success(null);
  }

  @override
  Future<Result<void>> advanceTo(DocumentKind kind, int nextNumber) async {
    if (nextNumber - 1 < value.lastValueOf(kind)) {
      return const Result.failure(ValidationFailure('backwards'));
    }
    value = NumberingSettings(
      prefixes: value.prefixes,
      padding: value.padding,
      lastValues: {...value.lastValues, kind: nextNumber - 1},
    );
    return const Result.success(null);
  }

  @override
  Object snapshot() => value;

  @override
  void restore(Object snapshot) => value = snapshot as NumberingSettings;
}

class FakeLogoStorage implements LogoStorage {
  final List<String> deleted = [];

  @override
  Future<Result<String>> store(String sourcePath) async =>
      Result.success('product_images/logo_stored.png');

  @override
  Future<String> resolvePath(String relativePath) async =>
      '/docs/$relativePath';

  @override
  Future<List<int>?> read(String relativePath) async => [1, 2, 3];

  @override
  Future<void> delete(String relativePath) async => deleted.add(relativePath);
}

/// Real settings use cases on fakes with rollback.
class SettingsFixture {
  SettingsFixture() {
    currencies = FakeCurrencyRepository(settings);
    transactions = FakeTransactionRunner([
      preferences,
      business,
      currencies,
      numbering,
      audit,
    ]);
    saveBusiness = SaveBusinessProfile(
      repository: business,
      logos: logos,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    changeCurrency = ChangeCurrency(
      currencies: currencies,
      settings: settings,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    updatePreferences = UpdatePreferences(
      repository: preferences,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    saveNumbering = SaveNumbering(
      repository: numbering,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    setNextNumber = SetNextDocumentNumber(
      repository: numbering,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    updateTaxRate = UpdateTaxRate(
      repository: taxRates,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    setTaxArchived = SetTaxRateArchived(
      repository: taxRates,
      preferences: preferences,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    setDefaultTax = SetDefaultTaxRate(
      taxRates: taxRates,
      preferences: preferences,
      transactions: transactions,
    );
  }

  final FakeSettingsRepository settings = FakeSettingsRepository();
  final FakePreferencesRepository preferences = FakePreferencesRepository();
  final FakeBusinessProfileRepository business =
      FakeBusinessProfileRepository();
  final FakeNumberingRepository numbering = FakeNumberingRepository();
  final FakeLogoStorage logos = FakeLogoStorage();
  final FakeAuditLogRepository audit = FakeAuditLogRepository();
  final FakeTaxRateRepository taxRates = FakeTaxRateRepository();
  final FakeClock clock = FakeClock();
  final SequentialIds ids = SequentialIds();
  late final FakeCurrencyRepository currencies;
  late final FakeTransactionRunner transactions;
  late final SaveBusinessProfile saveBusiness;
  late final ChangeCurrency changeCurrency;
  late final UpdatePreferences updatePreferences;
  late final SaveNumbering saveNumbering;
  late final SetNextDocumentNumber setNextNumber;
  late final UpdateTaxRate updateTaxRate;
  late final SetTaxRateArchived setTaxArchived;
  late final SetDefaultTaxRate setDefaultTax;
}
