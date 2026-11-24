import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/audit/data/repositories/audit_event_log_repository.dart';
import 'package:inventrix/features/audit/data/repositories/drift_audit_event_repository.dart';
import 'package:inventrix/features/audit/data/services/settings_audit_actor_provider.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';
import 'package:inventrix/features/product_classification/data/repositories/drift_product_classification_repository.dart';
import 'package:inventrix/features/product_classification/domain/entities/product_classification.dart';
import 'package:inventrix/features/product_classification/domain/usecases/classification_use_cases.dart';
import 'package:inventrix/features/products/data/repositories/drift_product_repository.dart';
import 'package:inventrix/features/products/domain/usecases/set_product_tax_treatment.dart';
import 'package:inventrix/features/products/presentation/bloc/product_tax_cubit.dart';
import 'package:inventrix/features/settings/data/repositories/drift_settings_repository.dart';
import 'package:inventrix/features/taxation/data/repositories/drift_tax_config_repository.dart';
import 'package:inventrix/features/taxation/data/repositories/drift_tax_repository.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/usecases/tax_config_editor.dart';
import 'package:inventrix/features/taxation/presentation/bloc/tax_settings_cubit.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../core/database/database_test_helpers.dart';
import '../features/audit/audit_test_support.dart';

/// The screens' state holders over the real schema. Written without a
/// Flutter SDK: not yet executed.
void main() {
  late AppDatabase db;
  late DriftTaxRepository tax;
  late TaxConfigEditor editor;
  late TaxSettingsCubit settingsCubit;
  late ProductTaxCubit productCubit;
  late DriftProductClassificationRepository classifications;

  Future<List<Map<String, Object?>>> events(String where) async => [
    for (final r in await db.customSelect('SELECT * FROM audit_events WHERE $where ORDER BY seq').get()) r.data,
  ];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    await insertUnit(db, 'u1');
    await insertProduct(db, 'p1', sku: 'A');
    final eventsRepo = DriftAuditEventRepository(db);
    final recorder = AuditRecorder(
      repository: eventsRepo,
      actors: SettingsAuditActorProvider(db),
      hasher: hasher,
      clock: StepClock(DateTime.utc(2026, 6, 1)),
      ids: CountingIds(),
    );
    final audit = AuditEventLogRepository(recorder: recorder, events: eventsRepo, legacy: DriftAuditLogRepository(db));
    final tx = DriftTransactionRunner(db, ids: CountingIds());
    final clock = StepClock(DateTime.utc(2026, 6, 1));
    final ids = CountingIds();
    tax = DriftTaxRepository(db);
    editor = TaxConfigEditor(
      read: tax,
      write: DriftTaxConfigRepository(db),
      preferences: DriftTaxPreferencesRepository(db),
      transactions: tx,
      audit: audit,
      clock: clock,
      ids: ids,
    );
    final settings = DriftSettingsRepository(db);
    settingsCubit = TaxSettingsCubit(read: tax, preferences: DriftTaxPreferencesRepository(db), settings: settings, editor: editor);
    classifications = DriftProductClassificationRepository(db);
    productCubit = ProductTaxCubit(
      products: DriftProductRepository(db, settings),
      tax: tax,
      classifications: classifications,
      setTreatment: SetProductTaxTreatment(products: DriftProductRepository(db, settings), tax: tax, transactions: tx, audit: audit, clock: clock, ids: ids),
      add: AddProductClassification(repository: classifications, ids: ids, clock: clock, audit: audit, transactions: tx),
      update: UpdateProductClassification(repository: classifications, clock: clock, ids: ids, audit: audit, transactions: tx),
      remove: RemoveProductClassification(classifications, clock: clock, ids: ids, audit: audit, transactions: tx),
      setPrimary: SetPrimaryProductClassification(classifications, clock: clock, ids: ids, audit: audit, transactions: tx),
    );
  });

  tearDown(() async {
    await settingsCubit.close();
    await productCubit.close();
    await db.close();
  });

  Future<void> seed() async {
    await settingsCubit.load();
    expect(await settingsCubit.saveRegime(const TaxRegime(id: 'r', name: 'GST', countryCode: 'IN', currencyCode: 'INR')), isNull);
    expect(await settingsCubit.saveCategory(const TaxCategory(id: 'std', name: 'Standard', code: 'STD', defaultTaxTreatment: TaxTreatment.standardRated)), isNull);
    expect(await settingsCubit.saveCategory(const TaxCategory(id: 'ex', name: 'Exempt', code: 'EX', defaultTaxTreatment: TaxTreatment.exempt)), isNull);
    expect(await settingsCubit.saveProfile(const TaxProfile(id: 'prof', name: 'Main', regimeId: 'r', isDefault: true, defaultTaxCategoryId: 'std')), isNull);
    expect(await settingsCubit.saveOverride(const TaxOverride(id: 'o1', name: 'Export', taxCategoryId: 'ex', reason: 'Export certificate')), isNull);
  }

  group('TaxSettingsCubit', () {
    test('loads an empty configuration, currency and preferences', () async {
      await settingsCubit.load();
      expect(settingsCubit.state.status, ViewStatus.loaded);
      expect(settingsCubit.state.configuration!.regimes, isEmpty);
      expect(settingsCubit.state.currencyDecimals, 2);
      expect(settingsCubit.state.preferences.sellerRegistered, isTrue);
    });

    test('a successful save reloads the data and announces it once', () async {
      await settingsCubit.load();
      final before = settingsCubit.state.messageSerial;
      expect(await settingsCubit.saveRegime(const TaxRegime(id: 'r', name: 'GST', countryCode: 'IN', currencyCode: 'INR')), isNull);
      expect(settingsCubit.state.configuration!.regimes.single.name, 'GST');
      expect(settingsCubit.state.message, 'Tax system saved.');
      expect(settingsCubit.state.messageSerial, before + 1);
    });

    test('a validation failure is returned to the form and does not pop a message', () async {
      await settingsCubit.load();
      final before = settingsCubit.state.messageSerial;
      final failure = await settingsCubit.saveCategory(const TaxCategory(id: 'c', name: '', code: '', defaultTaxTreatment: TaxTreatment.exempt));
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors.keys, containsAll(['name', 'code']));
      expect(settingsCubit.state.messageSerial, before);
    });

    test('a refused switch-off is reported as a message', () async {
      await seed();
      final failure = await settingsCubit.setActive(TaxConfigKind.profile, 'prof', active: false);
      expect(failure, isNotNull);
      expect(settingsCubit.state.message, contains('default profile'));
    });

    test('preferences are saved and read back', () async {
      await settingsCubit.load();
      expect(await settingsCubit.savePreferences(const TaxPreferences(countryCode: 'IN', regionCode: 'KA', sellerRegistered: false)), isNull);
      final p = settingsCubit.state.preferences;
      expect((p.countryCode, p.regionCode, p.sellerRegistered), ('IN', 'KA', false));
    });

    test('new ids are unique', () {
      expect(settingsCubit.newId(), isNot(settingsCubit.newId()));
    });
  });

  group('ProductTaxCubit', () {
    test('without a tax profile the product is reported as not using the new system', () async {
      await productCubit.load('p1');
      expect(productCubit.state.status, ViewStatus.loaded);
      expect(productCubit.state.hasProfile, isFalse);
      expect(productCubit.state.effective, isNull);
    });

    test('a product with no category inherits the profile default', () async {
      await seed();
      await productCubit.load('p1');
      expect(productCubit.state.hasProfile, isTrue);
      expect(productCubit.state.effective!.source.label, 'Inherited from the tax profile');
      expect(productCubit.state.effectiveCategory!.name, 'Standard');
    });

    test('choosing a category, then an override, then clearing both', () async {
      await seed();
      await productCubit.load('p1');

      await productCubit.setCategory('ex');
      expect(productCubit.state.product!.taxCategoryId, 'ex');
      expect(productCubit.state.effective!.source.label, 'Assigned to the product');
      expect(productCubit.state.effectiveCategory!.defaultTaxTreatment, TaxTreatment.exempt);
      expect(productCubit.state.message, 'Tax category saved.');

      await productCubit.setOverride('o1');
      expect(productCubit.state.effective!.source.label, 'Explicit tax override');
      expect(productCubit.state.effective!.overrideId, 'o1');

      await productCubit.setOverride(null);
      await productCubit.setCategory(null);
      expect(productCubit.state.product!.taxCategoryId, isNull);
      expect(productCubit.state.effective!.source.label, 'Inherited from the tax profile');
    });

    test('every change is audited with before and after, flagged as a tax change', () async {
      await seed();
      await productCubit.load('p1');
      await productCubit.setCategory('ex');
      final e = (await events("entity_type = 'product' AND action = 'updated'")).single;
      expect(e['previous_values'], '{"taxCategoryId":null}');
      expect(e['new_values'], '{"taxCategoryId":"ex"}');
      expect(e['metadata'], contains('"taxTreatmentChanged":true'));
    });

    test('choosing the same thing again records nothing', () async {
      await seed();
      await productCubit.load('p1');
      await productCubit.setCategory('ex');
      final count = (await events("entity_type = 'product'")).length;
      await productCubit.setCategory('ex');
      expect((await events("entity_type = 'product'")).length, count);
    });

    test('an unknown or switched-off category is refused', () async {
      await seed();
      await productCubit.load('p1');
      await productCubit.setCategory('nope');
      expect(productCubit.state.message, contains('active tax category'));
      expect(productCubit.state.product!.taxCategoryId, isNull);
      await editor.setActive(TaxConfigKind.category, 'ex', active: false);
      await productCubit.setCategory('ex');
      expect(productCubit.state.product!.taxCategoryId, isNull);
    });

    test('a category switched off after being chosen stays listed so it can be replaced', () async {
      await seed();
      await productCubit.load('p1');
      await productCubit.setCategory('ex');
      await editor.setActive(TaxConfigKind.category, 'ex', active: false);
      await productCubit.load('p1');
      expect(productCubit.state.categories.map((c) => c.id), contains('ex'));
    });

    test('classifications: the first is primary, others can be promoted, removal promotes the next', () async {
      await seed();
      await productCubit.load('p1');
      expect(await productCubit.addClassification(system: 'hsn', code: '8471', type: ClassificationType.goods, description: 'Computers'), isNull);
      expect(await productCubit.addClassification(system: 'hsn', code: '8472', type: ClassificationType.goods), isNull);
      expect(productCubit.state.classifications.map((c) => c.code), ['8471', '8472']);
      expect(productCubit.state.classifications.first.isPrimary, isTrue);

      await productCubit.makePrimary(productCubit.state.classifications.last);
      expect(productCubit.state.classifications.first.code, '8472');

      await productCubit.removeClassification(productCubit.state.classifications.first);
      expect(productCubit.state.classifications.single.code, '8471');
      expect(productCubit.state.classifications.single.isPrimary, isTrue);
      expect(
        (await events("entity_type = 'product_classification'")).map((e) => e['action']),
        ['added', 'added', 'primary_changed', 'removed'],
      );
    });

    test('a bad code comes back as field errors and nothing is saved', () async {
      await productCubit.load('p1');
      final failure = await productCubit.addClassification(system: 'sac', code: '12', type: ClassificationType.goods);
      expect(failure, isA<ValidationFailure>());
      expect((failure! as ValidationFailure).fieldErrors.keys, containsAll(['code', 'type']));
      expect(productCubit.state.classifications, isEmpty);
    });

    test('the same code twice is a duplicate; editing a code works', () async {
      await productCubit.load('p1');
      await productCubit.addClassification(system: 'hsn', code: '8471', type: ClassificationType.goods);
      final dup = await productCubit.addClassification(system: 'hsn', code: '8471', type: ClassificationType.goods);
      expect(dup, isA<DuplicateEntryFailure>());
      final existing = productCubit.state.classifications.single;
      expect(await productCubit.updateClassification(existing, system: 'hsn', code: '847130', type: ClassificationType.goods, description: 'Laptops'), isNull);
      expect(productCubit.state.classifications.single.code, '847130');
      expect(productCubit.state.classifications.single.description, 'Laptops');
    });

    test('codes used elsewhere are suggested, short searches are ignored', () async {
      await insertProduct(db, 'p2', sku: 'B');
      await classifications.add(
        ProductClassification(
          id: 'c9', productId: 'p2', system: ClassificationSystem.hsn, code: '8471', description: 'Computers',
          type: ClassificationType.goods, isPrimary: true, createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026),
        ),
      );
      await productCubit.load('p1');
      await productCubit.searchSuggestions('84');
      expect(productCubit.state.suggestions.single.code, '8471');
      await productCubit.searchSuggestions('8');
      expect(productCubit.state.suggestions, isEmpty);
    });

    test('a missing product is reported', () async {
      await productCubit.load('nope');
      expect(productCubit.state.status, ViewStatus.failure);
    });
  });
}
