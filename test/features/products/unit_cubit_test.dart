import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/domain/usecases/add_common_units.dart';
import 'package:inventrix/features/products/domain/usecases/archive_unit.dart';
import 'package:inventrix/features/products/domain/usecases/create_unit.dart';
import 'package:inventrix/features/products/domain/usecases/restore_unit.dart';
import 'package:inventrix/features/products/domain/usecases/update_unit.dart';
import 'package:inventrix/features/products/presentation/bloc/unit_cubit.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/domain_fixture.dart';

void main() {
  late DomainFixture f;

  UnitCubit build() {
    final create = CreateUnit(repository: f.units, ids: f.ids, clock: f.clock);
    return UnitCubit(
      repository: f.units,
      createUnit: create,
      updateUnit: UpdateUnit(repository: f.units, clock: f.clock),
      archiveUnit: ArchiveUnit(repository: f.units, clock: f.clock),
      restoreUnit: RestoreUnit(repository: f.units, clock: f.clock),
      addCommonUnits: AddCommonUnits(repository: f.units, createUnit: create),
    );
  }

  setUp(() => f = DomainFixture());

  test('empty list, then common units can be added', () async {
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, ViewStatus.empty);
    await cubit.addCommonUnits();
    expect(cubit.state.status, ViewStatus.loaded);
    expect(cubit.state.units.length, 8);
    await cubit.addCommonUnits();
    expect(cubit.state.units.length, 8);
  });

  test('create returns validation errors for a duplicate symbol', () async {
    final cubit = build();
    await cubit.create(name: 'Kilogram', symbol: 'kg', decimalPlaces: 3);
    final dup = await cubit.create(
      name: 'Kilo',
      symbol: 'KG',
      decimalPlaces: 3,
    );
    expect(dup.failureOrNull, isA<ValidationFailure>());
    expect(cubit.state.units.length, 1);
  });

  test('update, archive and restore refresh the list', () async {
    final cubit = build();
    final created = (await cubit.create(
      name: 'Piece',
      symbol: 'pcs',
      decimalPlaces: 0,
    )).valueOrNull!;
    await cubit.update(
      id: created.id,
      name: 'Pieces',
      symbol: 'pcs',
      decimalPlaces: 0,
    );
    expect(cubit.state.units.single.name, 'Pieces');
    await cubit.archive(created.id);
    expect(cubit.state.status, ViewStatus.empty);
    await cubit.setIncludeArchived(value: true);
    expect(cubit.state.units.single.isArchived, isTrue);
    await cubit.restore(created.id);
    expect(cubit.state.units.single.isArchived, isFalse);
  });

  test('a repository failure ends in failure', () async {
    f.units.searchFailure = const DatabaseFailure('offline');
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, ViewStatus.failure);
  });
}
