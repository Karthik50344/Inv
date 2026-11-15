import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/suppliers/domain/usecases/archive_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/create_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/restore_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/update_supplier.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

import '../../support/domain_fixture.dart';
import '../../support/fakes.dart';

void main() {
  late FakeClock clock;
  late FakeSettingsRepository settings;
  late FakeSupplierRepository repo;
  late CreateSupplier create;
  late UpdateSupplier update;

  setUp(() {
    clock = FakeClock();
    settings = FakeSettingsRepository();
    repo = FakeSupplierRepository();
    create = CreateSupplier(
      repository: repo,
      settings: settings,
      ids: SequentialIds(),
      clock: clock,
    );
    update = UpdateSupplier(repository: repo, settings: settings, clock: clock);
  });

  test('creates a supplier with trimmed, nullable fields', () async {
    final r = await create(
      const PartyDraft(
        name: '  Asha Traders ',
        phone: '+91 98765 43210',
        email: 'asha@example.com',
        city: ' Chennai ',
        openingBalance: '1500.50',
      ),
    );
    final value = r.valueOrNull!;
    expect(value.name, 'Asha Traders');
    expect(value.city, 'Chennai');
    expect(value.address, isNull);
    expect(value.openingBalance.minorUnits, 150050);
    expect(value.openingBalance.currencyCode, 'INR');
    expect(repo.items.length, 1);
  });

  test('blank opening balance is zero; credits may be negative', () async {
    final zero = await create(const PartyDraft(name: 'A'));
    expect(zero.valueOrNull?.openingBalance.isZero, isTrue);
    final credit = await create(
      const PartyDraft(name: 'B', openingBalance: '-20'),
    );
    expect(credit.valueOrNull?.openingBalance.minorUnits, -2000);
  });

  test('validates every field and persists nothing on failure', () async {
    final r = await create(
      PartyDraft(
        name: ' ',
        phone: '12',
        email: 'nope',
        address: 'x' * 301,
        openingBalance: '1.234',
      ),
    );
    final errors = fieldErrorsOf(r);
    for (final field in [
      'name',
      'phone',
      'email',
      'address',
      'openingBalance',
    ]) {
      expect(errors.containsKey(field), isTrue);
    }
    expect(repo.items, isEmpty);
  });

  test('uses the configured currency precision', () async {
    settings.config = const CurrencyConfig(
      currencyCode: 'JPY',
      decimalPlaces: 0,
    );
    final bad = await create(
      const PartyDraft(name: 'A', openingBalance: '1.5'),
    );
    expect(fieldErrorsOf(bad).containsKey('openingBalance'), isTrue);
  });

  test('update changes data, keeps id and createdAt', () async {
    final created = (await create(const PartyDraft(name: 'Old'))).valueOrNull!;
    clock.advance(const Duration(days: 2));
    final r = await update(created.id, const PartyDraft(name: 'New'));
    expect(r.valueOrNull?.name, 'New');
    expect(r.valueOrNull?.id, created.id);
    expect(r.valueOrNull?.createdAt, created.createdAt);
    expect(r.valueOrNull?.updatedAt, clock.now());
  });

  test('update validates and reports NotFound', () async {
    final created = (await create(const PartyDraft(name: 'Old'))).valueOrNull!;
    final invalid = await update(created.id, const PartyDraft(name: ''));
    expect(fieldErrorsOf(invalid).containsKey('name'), isTrue);
    final missing = await update('ghost', const PartyDraft(name: 'X'));
    expect(missing.failureOrNull, isA<NotFoundFailure>());
  });

  test('archive and restore are idempotent and keep data', () async {
    final created = (await create(const PartyDraft(name: 'A'))).valueOrNull!;
    final archive = ArchiveSupplier(repository: repo, clock: clock);
    final restore = RestoreSupplier(repository: repo, clock: clock);
    expect((await archive(created.id)).isSuccess, isTrue);
    expect((await archive(created.id)).isSuccess, isTrue);
    expect(repo.items[created.id]!.isArchived, isTrue);
    expect(repo.items[created.id]!.name, 'A');
    expect((await restore(created.id)).isSuccess, isTrue);
    expect(repo.items[created.id]!.isArchived, isFalse);
    expect((await archive('ghost')).failureOrNull, isA<NotFoundFailure>());
  });
}
