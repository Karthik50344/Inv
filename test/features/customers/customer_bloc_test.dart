import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/customers/domain/usecases/archive_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/create_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/restore_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/update_customer.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_bloc.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_detail_cubit.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_event.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_form_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/fakes.dart';

void main() {
  late FakeClock clock;
  late FakeSettingsRepository settings;
  late FakeCustomerRepository repo;
  late CreateCustomer create;
  late UpdateCustomer update;
  late ArchiveCustomer archive;
  late RestoreCustomer restore;

  CustomerBloc buildBloc() => CustomerBloc(
    repository: repo,
    archiveCustomer: archive,
    restoreCustomer: restore,
  );
  CustomerFormCubit buildForm() => CustomerFormCubit(
    repository: repo,
    settings: settings,
    createCustomer: create,
    updateCustomer: update,
  );
  CustomerDetailCubit buildDetail() => CustomerDetailCubit(
    repository: repo,
    archiveCustomer: archive,
    restoreCustomer: restore,
  );

  setUp(() {
    clock = FakeClock();
    settings = FakeSettingsRepository();
    repo = FakeCustomerRepository();
    create = CreateCustomer(
      repository: repo,
      settings: settings,
      ids: SequentialIds(),
      clock: clock,
    );
    update = UpdateCustomer(repository: repo, settings: settings, clock: clock);
    archive = ArchiveCustomer(repository: repo, clock: clock);
    restore = RestoreCustomer(repository: repo, clock: clock);
  });

  Future<String> add(String name, {String phone = ''}) async =>
      (await create(PartyDraft(name: name, phone: phone))).valueOrNull!.id;

  Future<void> settle(CustomerBloc bloc, ViewStatus status) =>
      bloc.stream.firstWhere((s) => s.status == status);

  group('CustomerBloc', () {
    test('starts in the initial state', () {
      expect(buildBloc().state.status, ViewStatus.initial);
    });

    test('empty when there are no customers', () async {
      final bloc = buildBloc()..add(const CustomersStarted());
      await settle(bloc, ViewStatus.empty);
      await bloc.close();
    });

    test('loads customers and searches by name or phone', () async {
      await add('Asha Traders', phone: '9876543210');
      await add('Bala Stores');
      final bloc = buildBloc()..add(const CustomersStarted());
      await settle(bloc, ViewStatus.loaded);
      expect(bloc.state.customers.length, 2);
      bloc.add(const CustomersSearchChanged('bala'));
      await bloc.stream.firstWhere((s) => s.customers.length == 1);
      expect(bloc.state.customers.single.name, 'Bala Stores');
      bloc.add(const CustomersSearchChanged('98765'));
      await bloc.stream.firstWhere(
        (s) =>
            s.customers.length == 1 &&
            s.customers.single.name == 'Asha Traders',
      );
      await bloc.close();
    });

    test('archive toggle hides and (with the filter) shows archived', () async {
      final id = await add('Asha');
      final bloc = buildBloc()..add(const CustomersStarted());
      await settle(bloc, ViewStatus.loaded);
      bloc.add(CustomerArchiveToggled(id, archive: true));
      await settle(bloc, ViewStatus.empty);
      bloc.add(const CustomersArchivedFilterChanged(includeArchived: true));
      await settle(bloc, ViewStatus.loaded);
      expect(bloc.state.customers.single.isArchived, isTrue);
      bloc.add(CustomerArchiveToggled(id, archive: false));
      await bloc.stream.firstWhere((s) => !s.customers.single.isArchived);
      await bloc.close();
    });

    test('archive failure surfaces a message', () async {
      final bloc = buildBloc()
        ..add(const CustomerArchiveToggled('ghost', archive: true));
      final state = await bloc.stream.firstWhere((s) => s.message != null);
      expect(state.message, isNotNull);
      await bloc.close();
    });

    test('repository failures end in the failure state', () async {
      repo.searchFailure = const DatabaseFailure('offline');
      final bloc = buildBloc()..add(const CustomersStarted());
      final state = await bloc.stream.firstWhere(
        (s) => s.status == ViewStatus.failure,
      );
      expect(state.message, 'offline');
      await bloc.close();
    });
  });

  group('CustomerFormCubit', () {
    test('create mode is ready with currency', () async {
      final cubit = buildForm();
      await cubit.load();
      expect(cubit.state.loadStatus, FormLoadStatus.ready);
      expect(cubit.state.isEditing, isFalse);
      expect(cubit.state.currency?.currencyCode, 'INR');
    });

    test('edit mode loads the customer; unknown id is notFound', () async {
      final id = await add('Asha');
      final cubit = buildForm();
      await cubit.load(customerId: id);
      expect(cubit.state.customer?.name, 'Asha');
      await cubit.load(customerId: 'ghost');
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
      final id = cubit.state.savedCustomerId!;
      await cubit.load(customerId: id);
      await cubit.submit(const PartyDraft(name: 'Asha Traders'));
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(repo.items.length, 1);
      expect(repo.items[id]!.name, 'Asha Traders');
    });
  });

  group('CustomerDetailCubit', () {
    test('loads by id and reports unknown ids as notFound', () async {
      final id = await add('Asha');
      final cubit = buildDetail();
      await cubit.load(id);
      expect(cubit.state.status, DetailStatus.loaded);
      await cubit.load('ghost');
      expect(cubit.state.status, DetailStatus.notFound);
    });

    test('archive and restore reload the customer', () async {
      final id = await add('Asha');
      final cubit = buildDetail();
      await cubit.load(id);
      await cubit.archive();
      expect(cubit.state.customer?.isArchived, isTrue);
      await cubit.restore();
      expect(cubit.state.customer?.isArchived, isFalse);
    });
  });
}
