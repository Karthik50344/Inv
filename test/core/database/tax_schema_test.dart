import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/taxation/data/repositories/drift_tax_repository.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_calculation.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_types.dart';
import 'package:inventrix/features/taxation/domain/services/tax_calculator.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

import 'database_test_helpers.dart';

/// Schema v10: the configurable tax model and the carry-over of the old
/// `tax_rates`. Needs Drift code generation (`build_runner`) to run.
void main() {
  late Directory tempDir;
  late File file;

  Future<int> count(AppDatabase db, String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM $table')
        .getSingle();
    return row.read<int>('c');
  }

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('inventrix_tax_test_');
    file = File('${tempDir.path}/inventory_management.sqlite');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> rewindToV9(AppDatabase db) async {
    // Simulates a v9 file: remove the v10 tables and the product columns'
    // data, then rewind the version. (Columns stay; the migration is
    // idempotent about them.)
    await db.customStatement('UPDATE products SET tax_category_id = NULL');
    await db.customStatement('UPDATE products SET tax_override_id = NULL');
    for (final table in [
      'tax_components',
      'tax_rules',
      'tax_overrides',
      'tax_profiles',
      'tax_categories',
      'tax_jurisdictions',
      'tax_regimes',
    ]) {
      await db.customStatement('DROP TABLE $table');
    }
    await db.customStatement('PRAGMA user_version = 9');
  }

  test('a fresh database has the tax tables and no seeded tax rules', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    for (final table in [
      'tax_regimes',
      'tax_jurisdictions',
      'tax_categories',
      'tax_profiles',
      'tax_overrides',
      'tax_rules',
      'tax_components',
    ]) {
      expect(await count(db, table), 0, reason: table);
    }
    await db.close();
  });

  test('9 -> 10 turns every old tax rate into a category, rule and '
      'component and links the products', () async {
    var db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    await insertUnit(db, 'u1');
    await db.customStatement(
      'INSERT INTO tax_rates (id, name, rate_bp, is_exempt, archived_at, '
      "created_at, updated_at) VALUES ('t18', 'GST 18%', 1800, 0, NULL, 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO tax_rates (id, name, rate_bp, is_exempt, archived_at, '
      "created_at, updated_at) VALUES ('tex', 'Exempt', 0, 1, NULL, 1, 1)",
    );
    await insertProduct(db, 'p1', sku: 'A');
    await insertProduct(db, 'p2', sku: 'B');
    await insertProduct(db, 'p3', sku: 'C');
    await db.customStatement("UPDATE products SET tax_rate_id = 't18' WHERE id = 'p1'");
    await db.customStatement("UPDATE products SET tax_rate_id = 'tex' WHERE id = 'p2'");
    await rewindToV9(db);
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    await db.initialize();

    expect(await count(db, 'tax_regimes'), 1);
    expect(await count(db, 'tax_profiles'), 1);
    expect(await count(db, 'tax_categories'), 2);
    expect(await count(db, 'tax_rules'), 1); // the exempt rate needs no rule
    expect(await count(db, 'tax_components'), 1);
    final linked = await db
        .customSelect('SELECT id, tax_category_id FROM products ORDER BY id')
        .get();
    expect(linked.map((r) => r.readNullable<String>('tax_category_id')), [
      'tc-t18',
      'tc-tex',
      null,
    ]);
    // The old column is untouched.
    final old = await db
        .customSelect("SELECT tax_rate_id FROM products WHERE id = 'p1'")
        .getSingle();
    expect(old.read<String>('tax_rate_id'), 't18');
    expect(await db.integrityCheck(), ['ok']);
    await db.close();
  });

  test('the carried-over configuration calculates the old tax', () async {
    var db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    await db.customStatement(
      'INSERT INTO tax_rates (id, name, rate_bp, is_exempt, archived_at, '
      "created_at, updated_at) VALUES ('t18', 'GST 18%', 1800, 0, NULL, 1, 1)",
    );
    await rewindToV9(db);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    await db.initialize();

    final config = (await DriftTaxRepository(db).loadConfiguration())
        .valueOrNull!;
    final result = const TaxCalculator()
        .calculate(
          config,
          TaxCalculationInput(
            taxProfileId: 'tp-migrated',
            taxCategoryId: 'tc-t18',
            transactionType: TaxTransactionType.sale,
            transactionDate: DateTime.utc(2026, 6, 1),
            pricingMode: PricingMode.exclusive,
            sellerLocation: const TaxLocation(countryCode: 'ZZ'),
            placeOfSupply: const TaxLocation(countryCode: 'ZZ'),
            grossAmount: Money.fromMinor(
              10000,
              currencyCode: 'INR',
              decimalPlaces: 2,
            ),
            quantity: Quantity.fromUnits(1),
          ),
        )
        .valueOrNull!;
    expect(result.taxCharged.minorUnits, 1800);
    await db.close();
  });

  test('the database rejects bad tax data', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    final now = DateTime.now().millisecondsSinceEpoch;
    Future<void> category(String id, String treatment) => db.customStatement(
      'INSERT INTO tax_categories (id, name, code, default_tax_treatment, '
      'is_active, created_at, updated_at) VALUES (?, ?, ?, ?, 1, ?, ?)',
      [id, id, id, treatment, now, now],
    );
    await expectLater(category('bad', 'free_money'), throwsA(anything));
    await category('c1', 'standard_rated');
    // A second category with the same code is refused.
    await expectLater(
      db.customStatement(
        'INSERT INTO tax_categories (id, name, code, default_tax_treatment, '
        "is_active, created_at, updated_at) VALUES ('x', 'x', 'c1', 'exempt', "
        '1, 1, 1)',
      ),
      throwsA(anything),
    );
    await db.close();
  });

  test('only one tax profile can be the default', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    await db.customStatement(
      "INSERT INTO tax_regimes (id, name, country_code, currency_code, is_active, created_at, updated_at) VALUES ('r', 'R', 'IN', 'INR', 1, 1, 1)",
    );
    Future<void> profile(String id) => db.customStatement(
      'INSERT INTO tax_profiles (id, name, regime_id, is_default, is_active, '
      "created_at, updated_at) VALUES (?, ?, 'r', 1, 1, 1, 1)",
      [id, id],
    );
    await profile('a');
    await expectLater(profile('b'), throwsA(anything));
    await db.close();
  });

  test('a rule cannot be moved to another category', () async {
    final db = AppDatabase(NativeDatabase(file));
    await db.initialize();
    await db.customStatement(
      "INSERT INTO tax_regimes (id, name, country_code, currency_code, is_active, created_at, updated_at) VALUES ('r', 'R', 'IN', 'INR', 1, 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tax_profiles (id, name, regime_id, is_default, is_active, created_at, updated_at) VALUES ('p', 'P', 'r', 0, 1, 1, 1)",
    );
    for (final id in ['c1', 'c2']) {
      await db.customStatement(
        "INSERT INTO tax_categories (id, name, code, default_tax_treatment, is_active, created_at, updated_at) VALUES ('$id', '$id', '$id', 'standard_rated', 1, 1, 1)",
      );
    }
    await db.customStatement(
      "INSERT INTO tax_rules (id, tax_profile_id, tax_category_id, calculation_method, effective_from, created_at, updated_at) VALUES ('rule', 'p', 'c1', 'percentage', 0, 1, 1)",
    );
    await expectLater(
      db.customStatement("UPDATE tax_rules SET tax_category_id = 'c2'"),
      throwsA(anything),
    );
    // Ending date before the start date is refused as well.
    await expectLater(
      db.customStatement(
        "INSERT INTO tax_rules (id, tax_profile_id, tax_category_id, calculation_method, effective_from, effective_until, created_at, updated_at) VALUES ('r2', 'p', 'c1', 'percentage', 10, 5, 1, 1)",
      ),
      throwsA(anything),
    );
    await db.close();
  });

  test('the failure type for a missing rule is exposed to callers', () {
    expect(const TaxConfigurationFailure('x'), isA<Failure>());
  });
}
