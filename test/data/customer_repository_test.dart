import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/customers/data/repositories/drift_customer_repository.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/settings/data/repositories/drift_settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

import 'data_test_support.dart';

void main() {
  late AppDatabase db;
  late DriftCustomerRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftCustomerRepository(db, DriftSettingsRepository(db));
  });
  tearDown(() => db.close());

  Customer build({
    String id = 'x1',
    String name = 'Asha Traders',
    String? phone,
    String? email,
    int openingMinor = 0,
    DateTime? archived,
  }) => Customer(
    id: id,
    name: name,
    phone: phone,
    email: email,
    city: 'Chennai',
    openingBalance: Money.fromMinor(
      openingMinor,
      currencyCode: 'INR',
      decimalPlaces: 2,
    ),
    createdAt: t0,
    updatedAt: t0,
    archivedAt: archived,
  );

  test(
    'round-trips all fields, including a negative opening balance',
    () async {
      final original = build(
        phone: '+91 98765 43210',
        email: 'asha@example.com',
        openingMinor: -2500,
      );
      expect((await repo.create(original)).isSuccess, isTrue);
      final loaded = (await repo.getById('x1')).valueOrNull!;
      expect(loaded, original);
      expect(loaded.openingBalance.minorUnits, -2500);
      expect(loaded.openingBalance.currencyCode, 'INR');
    },
  );

  test('unknown ids are NotFound for read and update', () async {
    expect((await repo.getById('ghost')).failureOrNull, isA<NotFoundFailure>());
    expect(
      (await repo.update(build(id: 'ghost'))).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('duplicate ids are rejected', () async {
    await repo.create(build());
    expect(
      (await repo.create(build())).failureOrNull,
      isA<DuplicateEntryFailure>(),
    );
  });

  test('searches name, phone and email, ordered by name', () async {
    await repo.create(build(id: 'a', name: 'Zed Stores', phone: '99999 11111'));
    await repo.create(build(id: 'b', name: 'Alpha', email: 'alpha@mail.com'));
    final all = (await repo.search()).valueOrNull!;
    expect(all.map((c) => c.name).toList(), ['Alpha', 'Zed Stores']);
    expect((await repo.search(query: 'zed')).valueOrNull!.single.id, 'a');
    expect((await repo.search(query: '11111')).valueOrNull!.single.id, 'a');
    expect((await repo.search(query: 'mail.com')).valueOrNull!.single.id, 'b');
    expect((await repo.search(query: 'nothing')).valueOrNull, isEmpty);
  });

  test('update, archive and restore keep the row', () async {
    await repo.create(build());
    await repo.update(build(name: 'Renamed', openingMinor: 100));
    expect((await repo.getById('x1')).valueOrNull?.name, 'Renamed');

    await repo.update(build(name: 'Renamed').archived(t0));
    expect((await repo.search()).valueOrNull, isEmpty);
    expect((await repo.search(includeArchived: true)).valueOrNull!.length, 1);

    await repo.update(build(name: 'Renamed').restored(t0));
    expect((await repo.search()).valueOrNull!.single.isArchived, isFalse);
  });

  test('settings failures propagate', () async {
    await db.customStatement(
      "UPDATE app_settings SET value = '9' WHERE key = 'currency_decimal_places'",
    );
    expect((await repo.search()).failureOrNull, isA<DatabaseFailure>());
  });
}
