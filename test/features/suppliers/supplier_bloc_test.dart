import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/suppliers/domain/usecases/archive_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/create_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/restore_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/update_supplier.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_bloc.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_detail_cubit.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_event.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_form_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/fakes.dart';

void main() {
  late FakeClock clock;
  late FakeSettingsRepository settings;
  late FakeSupplierRepository repo;
  late CreateSupplier create;
  late UpdateSupplier update;
  late ArchiveSupplier archive;
  late RestoreSupplier restore;

  SupplierBloc buildBloc() => SupplierBloc(
    repository: repo,
    archiveSupplier: archive,
    restoreSupplier: restore,
  );
  SupplierFormCubit buildForm() => SupplierFormCubit(
    repository: repo,
    settings: settings,
    createSupplier: create,
    updateSupplier: update,
  );
  SupplierDetailCubit buildDetail() => SupplierDetailCubit(
    repository: repo,
    archiveSupplier: archive,
    restoreSupplier: restore,
  );

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
    archive = ArchiveSupplier(repository: repo, clock: clock);
    restore = RestoreSupplier(repository: repo, clock: clock);
  });

  Future<String> add(String name, {String phone = ''}) async =>
      (await create(PartyDraft(name: name, phone: phone))).valueOrNull!.id;

  Future<void> settle(SupplierBloc bloc, ViewStatus status) =>
      bloc.stream.firstWhere((s) => s.status == status);

  group('SupplierBloc', () {
    test('starts in the initial state', () {
      expect(buildBloc().state.status, ViewStatus.initial);
    });

    test('empty when there are no suppliers', () async {
      final bloc = buildBloc()..add(const SuppliersStarted());
      await settle(bloc, ViewStatus.empty);
      await bloc.close();
    });

    test('loads suppliers and searches by name or phone', () async {
      await add('Asha Traders', phone: '9876543210');
      await add('Bala Stores');
      final bloc = buildBloc()..add(const SuppliersStarted());
      await settle(bloc, ViewStatus.loaded);
      expect(bloc.state.suppliers.length, 2);
      bloc.add(const SuppliersSearchChanged('bala'));
      await bloc.stream.firstWhere((s) => s.suppliers.length == 1);
      expect(bloc.state.suppliers.single.name, 'Bala Stores');
      bloc.add(const SuppliersSearchChanged('98765'));
      await bloc.stream.firstWhere(
        (s) =>
            s.suppliers.length == 1 &&
            s.suppliers.single.name == 'Asha Traders',
      );
      await bloc.close();
    });

    test('archive toggle hides and (with the filter) shows archived', () async {
      final id = await add('Asha');
      final bloc = buildBloc()..add(const SuppliersStarted());
      await settle(bloc, ViewStatus.loaded);
      bloc.add(SupplierArchiveToggled(id, archive: true));
      await settle(bloc, ViewStatus.empty);
      bloc.add(const SuppliersArchivedFilterChanged(includeArchived: true));
      await settle(bloc, ViewStatus.loaded);
      expect(bloc.state.suppliers.single.isArchived, isTrue);
      bloc.add(SupplierArchiveToggled(id, archive: false));
      await bloc.stream.firstWhere((s) => !s.suppliers.single.isArchived);
      await bloc.close();
    });

    test('archive failure surfaces a message', () async {
      final bloc = buildBloc()
        ..add(const SupplierArchiveToggled('ghost', archive: true));
      final state = await bloc.stream.firstWhere((s) => s.message != null);
      expect(state.message, isNotNull);
      await bloc.close();
    });

    test('repository failures end in the failure state', () async {
      repo.searchFailure = const DatabaseFailure('offline');
      final bloc = buildBloc()..add(const SuppliersStarted());
      final state = await bloc.stream.firstWhere(
        (s) => s.status == ViewStatus.failure,
      );
      expect(state.message, 'offline');
      await bloc.close();
    });
  });

  group('SupplierFormCubit', () {
    test('create mode is ready with currency', () async {
      final cubit = buildForm();
      await cubit.load();
      expect(cubit.state.loadStatus, FormLoadStatus.ready);
      expect(cubit.state.isEditing, isFalse);
      expect(cubit.state.currency?.currencyCode, 'INR');
    });

    test('edit mode loads the supplier; unknown id is notFound', () async {
      final id = await add('Asha');
      final cubit = buildForm();
      await cubit.load(supplierId: id);
      expect(cubit.state.supplier?.name, 'Asha');
      await cubit.load(supplierId: 'ghost');
      expect(cubit.state.loadStatus, FormLoadStatus.notFound);
    });

    test('invalid submit exposes field errors and saves nothing', () async {
      final cubit = buildForm();
      await cubit.load();
      await cubit.submit(const PartyDraft(name: '', email: 'nope'));
      expect(cubit.state.submitStatus, SubmitStatus.validationError);
      expect(cubit.state.fieldErrors.containsKey('name'), isTrue);
      expect(cubit.state.fieldErrors.containsKey('email'), isTrue);
      expect(repo.items, isEmpty);
    });

    test('valid submit creates, then edit submit updates', () async {
      final cubit = buildForm();
      await cubit.load();
      await cubit.submit(const PartyDraft(name: 'Asha'));
      expect(cubit.state.submitStatus, SubmitStatus.success);
      final id = cubit.state.savedSupplierId!;
      await cubit.load(supplierId: id);
      await cubit.submit(const PartyDraft(name: 'Asha Traders'));
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(repo.items.length, 1);
      expect(repo.items[id]!.name, 'Asha Traders');
    });
  });

  group('SupplierDetailCubit', () {
    test('loads by id and reports unknown ids as notFound', () async {
      final id = await add('Asha');
      final cubit = buildDetail();
      await cubit.load(id);
      expect(cubit.state.status, DetailStatus.loaded);
      await cubit.load('ghost');
      expect(cubit.state.status, DetailStatus.notFound);
    });

    test('archive and restore reload the supplier', () async {
      final id = await add('Asha');
      final cubit = buildDetail();
      await cubit.load(id);
      await cubit.archive();
      expect(cubit.state.supplier?.isArchived, isTrue);
      await cubit.restore();
      expect(cubit.state.supplier?.isArchived, isFalse);
    });
  });
}
