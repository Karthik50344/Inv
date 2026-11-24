import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/audit/data/repositories/audit_event_log_repository.dart';
import 'package:inventrix/features/audit/data/repositories/drift_audit_event_repository.dart';
import 'package:inventrix/features/audit/data/services/settings_audit_actor_provider.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';
import 'package:inventrix/features/taxation/data/repositories/drift_tax_config_repository.dart';
import 'package:inventrix/features/taxation/data/repositories/drift_tax_repository.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/tax_calculator.dart';
import 'package:inventrix/features/taxation/domain/usecases/tax_config_editor.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import '../features/audit/audit_test_support.dart';

Money inr(int minor) => Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

/// Real schema (in-memory SQLite). Written without a Flutter SDK: not yet
/// executed.
void main() {
  late AppDatabase db;
  late TaxConfigEditor editor;
  late DriftTaxRepository read;

  Future<List<Map<String, Object?>>> audit(String where) async => [
    for (final r in await db.customSelect('SELECT * FROM audit_events WHERE $where ORDER BY seq').get()) r.data,
  ];

  Future<void> seedBasics() async {
    expect((await editor.saveRegime(const TaxRegime(id: 'r', name: 'GST', countryCode: 'IN', currencyCode: 'INR'))).isSuccess, isTrue);
    expect((await editor.saveCategory(const TaxCategory(id: 'cat', name: 'Standard', code: 'STD', defaultTaxTreatment: TaxTreatment.standardRated))).isSuccess, isTrue);
    expect((await editor.saveProfile(const TaxProfile(id: 'prof', name: 'Main', regimeId: 'r', isDefault: true, defaultTaxCategoryId: 'cat'))).isSuccess, isTrue);
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    final events = DriftAuditEventRepository(db);
    final recorder = AuditRecorder(
      repository: events,
      actors: SettingsAuditActorProvider(db),
      hasher: hasher,
      clock: StepClock(DateTime.utc(2026, 6, 1)),
      ids: CountingIds(),
    );
    read = DriftTaxRepository(db);
    editor = TaxConfigEditor(
      read: read,
      write: DriftTaxConfigRepository(db),
      preferences: DriftTaxPreferencesRepository(db),
      transactions: DriftTransactionRunner(db, ids: CountingIds()),
      audit: AuditEventLogRepository(recorder: recorder, events: events, legacy: DriftAuditLogRepository(db)),
      clock: StepClock(DateTime.utc(2026, 6, 1)),
      ids: CountingIds(),
    );
  });

  tearDown(() => db.close());

  test('a full configuration can be built from nothing and then calculates tax', () async {
    await seedBasics();
    expect((await editor.saveJurisdiction(const TaxJurisdiction(id: 'ka', regimeId: 'r', countryCode: 'IN', regionCode: 'KA', jurisdictionType: JurisdictionType.state))).isSuccess, isTrue);
    final rule = TaxRule(
      id: 'rule', taxProfileId: 'prof', taxCategoryId: 'cat', calculationMethod: TaxCalculationMethod.percentage,
      effectiveFrom: DateTime.utc(2026), supplyRelation: SupplyRelation.intra,
    );
    expect((await editor.saveRule(rule)).isSuccess, isTrue);
    expect((await editor.saveComponent(const TaxComponent(id: 'cg', taxRuleId: 'rule', name: 'CGST', componentType: TaxComponentType.cgst, calculationOrder: 1, rateBasisPoints: 900))).isSuccess, isTrue);
    expect((await editor.saveComponent(const TaxComponent(id: 'sg', taxRuleId: 'rule', name: 'SGST', componentType: TaxComponentType.sgst, calculationOrder: 2, rateBasisPoints: 900))).isSuccess, isTrue);

    final config = (await read.loadConfiguration()).valueOrNull!;
    final result = const TaxCalculator().calculate(
      config,
      TaxCalculationInput(
        taxProfileId: 'prof', taxCategoryId: 'cat', transactionType: TaxTransactionType.sale,
        transactionDate: DateTime.utc(2026, 6, 1), pricingMode: PricingMode.exclusive,
        sellerLocation: const TaxLocation(countryCode: 'IN', regionCode: 'KA'),
        placeOfSupply: const TaxLocation(countryCode: 'IN', regionCode: 'KA'),
        grossAmount: inr(10000), quantity: Quantity.fromUnits(1),
      ),
    ).valueOrNull!;
    expect(result.taxCharged, inr(1800));
  });

  test('a save is validated and nothing is stored or audited when it fails', () async {
    final r = await editor.saveCategory(const TaxCategory(id: 'c', name: '', code: '', defaultTaxTreatment: TaxTreatment.exempt));
    expect(r.failureOrNull, isA<ValidationFailure>());
    expect((r.failureOrNull! as ValidationFailure).fieldErrors.keys, containsAll(['name', 'code']));
    expect((await read.loadConfiguration()).valueOrNull!.categories, isEmpty);
    expect(await audit("entity_type = 'tax_category'"), isEmpty);
  });

  test('creating records an audit event; editing records only what changed', () async {
    await seedBasics();
    final created = await audit("entity_type = 'tax_category'");
    expect(created.single['action'], 'created');
    expect(created.single['new_values'], contains('"code":"STD"'));

    await editor.saveCategory(const TaxCategory(id: 'cat', name: 'Standard rate', code: 'STD', defaultTaxTreatment: TaxTreatment.standardRated));
    final events = await audit("entity_type = 'tax_category'");
    expect(events, hasLength(2));
    expect(events.last['action'], 'updated');
    expect(events.last['previous_values'], '{"name":"Standard"}');
    expect(events.last['new_values'], '{"name":"Standard rate"}');
  });

  test('saving without any change records nothing', () async {
    await seedBasics();
    final before = (await audit('1 = 1')).length;
    await editor.saveCategory(const TaxCategory(id: 'cat', name: 'Standard', code: 'STD', defaultTaxTreatment: TaxTreatment.standardRated));
    expect((await audit('1 = 1')).length, before);
  });

  test('the creation time is kept when a record is edited', () async {
    await seedBasics();
    Future<int> created() async => (await db.customSelect("SELECT created_at AS c FROM tax_categories WHERE id = 'cat'").getSingle()).read<int>('c');
    final first = await created();
    await editor.saveCategory(const TaxCategory(id: 'cat', name: 'Renamed', code: 'STD', defaultTaxTreatment: TaxTreatment.standardRated));
    expect(await created(), first);
  });

  test('making another profile the default clears the old default', () async {
    await seedBasics();
    await editor.saveProfile(const TaxProfile(id: 'p2', name: 'Second', regimeId: 'r', isDefault: true, defaultTaxCategoryId: 'cat'));
    final config = (await read.loadConfiguration()).valueOrNull!;
    expect(config.profiles.where((p) => p.isDefault).map((p) => p.id), ['p2']);
  });

  test('a rule that ties with another is refused, a later one is accepted', () async {
    await seedBasics();
    TaxRule rule(String id, DateTime from, {DateTime? until}) => TaxRule(
      id: id, taxProfileId: 'prof', taxCategoryId: 'cat', calculationMethod: TaxCalculationMethod.percentage,
      effectiveFrom: from, effectiveUntil: until,
    );
    expect((await editor.saveRule(rule('a', DateTime.utc(2026), until: DateTime.utc(2026, 12, 31)))).isSuccess, isTrue);
    final tie = await editor.saveRule(rule('b', DateTime.utc(2026, 6)));
    expect((tie.failureOrNull! as ValidationFailure).fieldErrors['priority'], isNotNull);
    expect((await editor.saveRule(rule('c', DateTime.utc(2027)))).isSuccess, isTrue);
  });

  test('editing a rule changes its conditions but never its owner', () async {
    await seedBasics();
    final rule = TaxRule(id: 'a', taxProfileId: 'prof', taxCategoryId: 'cat', calculationMethod: TaxCalculationMethod.percentage, effectiveFrom: DateTime.utc(2026));
    await editor.saveRule(rule);
    await editor.saveRule(TaxRule(id: 'a', taxProfileId: 'prof', taxCategoryId: 'cat', calculationMethod: TaxCalculationMethod.percentage, effectiveFrom: DateTime.utc(2026), priority: 5, supplyType: 'goods'));
    final saved = (await read.loadConfiguration()).valueOrNull!.rules.single;
    expect(saved.priority, 5);
    expect(saved.supplyType, 'goods');
    expect(saved.effectiveFrom, DateTime.utc(2026));
  });

  test('records are switched off, not deleted, and the change is audited', () async {
    await seedBasics();
    await editor.saveCategory(const TaxCategory(id: 'c2', name: 'Other', code: 'OTH', defaultTaxTreatment: TaxTreatment.exempt));
    expect((await editor.setActive(TaxConfigKind.category, 'c2', active: false)).isSuccess, isTrue);
    expect((await read.loadConfiguration()).valueOrNull!.category('c2')!.isActive, isFalse);
    final e = (await audit("entity_type = 'tax_category' AND action = 'deactivated'")).single;
    expect(e['previous_values'], '{"isActive":true}');
    expect((await editor.setActive(TaxConfigKind.category, 'c2', active: true)).isSuccess, isTrue);
  });

  test('the default profile and its default category cannot be switched off', () async {
    await seedBasics();
    expect((await editor.setActive(TaxConfigKind.profile, 'prof', active: false)).failureOrNull, isA<ValidationFailure>());
    expect((await editor.setActive(TaxConfigKind.category, 'cat', active: false)).failureOrNull, isA<ValidationFailure>());
  });

  test('a failed audit write rolls the change back', () async {
    await seedBasics();
    await db.customStatement('ALTER TABLE audit_events RENAME TO audit_events_gone');
    final r = await editor.saveCategory(const TaxCategory(id: 'c3', name: 'Third', code: 'THR', defaultTaxTreatment: TaxTreatment.exempt));
    expect(r.isFailure, isTrue);
    await db.customStatement('ALTER TABLE audit_events_gone RENAME TO audit_events');
    expect((await read.loadConfiguration()).valueOrNull!.category('c3'), isNull);
  });

  group('preferences', () {
    test('start with a registered business and no location', () async {
      final p = (await DriftTaxPreferencesRepository(db).load()).valueOrNull!;
      expect(p.countryCode, isNull);
      expect(p.sellerRegistered, isTrue);
    });

    test('are saved, audited with before and after, and read by the engine context', () async {
      final r = await editor.savePreferences(const TaxPreferences(countryCode: 'IN', regionCode: 'KA'));
      expect(r.isSuccess, isTrue);
      final p = (await DriftTaxPreferencesRepository(db).load()).valueOrNull!;
      expect((p.countryCode, p.regionCode, p.sellerRegistered), ('IN', 'KA', true));
      final e = (await audit("entity_type = 'tax_preferences'")).single;
      expect(e['new_values'], contains('"countryCode":"IN"'));
      await editor.savePreferences(const TaxPreferences(countryCode: 'IN', regionCode: 'KA', sellerRegistered: false));
      await seedBasics();
      final ctx = (await read.loadContext()).valueOrNull!;
      expect(ctx.sellerLocation.regionCode, 'KA');
      expect(ctx.isSellerTaxRegistered, isFalse);
    });

    test('saving the same values records nothing, bad codes are refused, blank clears', () async {
      await editor.savePreferences(const TaxPreferences(countryCode: 'IN'));
      final count = (await audit("entity_type = 'tax_preferences'")).length;
      await editor.savePreferences(const TaxPreferences(countryCode: 'IN'));
      expect((await audit("entity_type = 'tax_preferences'")).length, count);
      expect((await editor.savePreferences(const TaxPreferences(countryCode: 'india'))).failureOrNull, isA<ValidationFailure>());
      await editor.savePreferences(const TaxPreferences());
      expect((await DriftTaxPreferencesRepository(db).load()).valueOrNull!.countryCode, isNull);
    });
  });
}
