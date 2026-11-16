import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/customers/domain/usecases/archive_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/restore_customer.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/sales/domain/entities/sales_input.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_bloc.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_detail_cubit.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_event.dart';
import 'package:inventrix/features/sales/presentation/bloc/sales_form_cubit.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/bloc_test_helper.dart';
import '../../support/sales_fakes.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  late SalesFixture f;
  late String productId;

  setUp(() async {
    f = SalesFixture();
    productId = (await f.addProduct(selling: '10')).id;
    await f.stockUp(productId, '1000');
  });

  SalesLineInput line(String qty, {String price = ''}) =>
      SalesLineInput(productId: productId, quantity: qty, unitPrice: price);

  SalesBloc buildList() => SalesBloc(sales: f.sales, settings: f.settings);

  SalesDetailCubit buildDetail() => SalesDetailCubit(
    sales: f.sales,
    settings: f.settings,
    transition: f.transition,
    post: f.post,
    voidSale: f.voidSale,
    shareInvoice: f.shareInvoice,
  );

  SalesFormCubit buildForm() => SalesFormCubit(
    sales: f.sales,
    customers: f.customers,
    products: f.products,
    units: f.units,
    settings: f.settings,
    lineBuilder: f.lineBuilder,
    stockCheck: f.stockCheck,
    saveDraft: f.saveDraft,
  );

  group('SalesBloc', () {
    test('starts initial', () {
      expect(buildList().state.status, ViewStatus.initial);
    });

    blocTest<SalesBloc, SalesState>(
      'empty when there are no sales',
      build: buildList,
      act: (b) => b.add(const SalesStarted()),
      verify: (b) {
        expect(b.state.status, ViewStatus.empty);
        expect(b.state.items, isEmpty);
      },
    );

    test('loads sales, searches and filters by status', () async {
      final a = await f.draft([line('1')]);
      final b = await f.draft([line('2')]);
      (await f.post(b.id)).valueOrNull!;
      final bloc = buildList()..add(const SalesStarted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ViewStatus.loaded);
      expect(bloc.state.items.length, 2);

      bloc.add(const SalesStatusChanged(DocumentStatus.posted));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items.single.id, b.id);

      bloc.add(const SalesStatusChanged(null));
      bloc.add(const SalesSearchChanged('INV-000001'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items.single.id, b.id);

      bloc.add(const SalesSearchChanged('zzz'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ViewStatus.empty);
      expect(a.id, isNotEmpty);
      await bloc.close();
    });

    test('toggling approval persists the setting', () async {
      final bloc = buildList()..add(const SalesApprovalToggled(required: true));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(f.settings.salesApprovalRequired, isTrue);
      expect(bloc.state.approvalRequired, isTrue);
      await bloc.close();
    });
  });

  group('SalesDetailCubit', () {
    test('loads a sale', () async {
      final d = await f.draft([line('1')]);
      final cubit = buildDetail();
      await cubit.load(d.id);
      expect(cubit.state.status, DetailStatus.loaded);
      expect(cubit.state.invoice!.id, d.id);
      await cubit.close();
    });

    test('unknown id ends in notFound', () async {
      final cubit = buildDetail();
      await cubit.load('nope');
      expect(cubit.state.status, DetailStatus.notFound);
      await cubit.close();
    });

    test('post updates the invoice and reports success', () async {
      final d = await f.draft([line('3')]);
      final cubit = buildDetail();
      await cubit.load(d.id);
      await cubit.post();
      expect(cubit.state.invoice!.status, DocumentStatus.posted);
      expect(cubit.state.message, 'Posted. Stock has been reduced.');
      expect(cubit.state.busy, isFalse);
      await cubit.close();
    });

    test('a failed post keeps the draft and shows the reason', () async {
      final d = await f.draft([line('3')]);
      final cubit = buildDetail();
      await cubit.load(d.id);
      f.products.items[productId] = f.products.items[productId]!.archived(
        f.clock.now(),
      );
      await cubit.post();
      expect(cubit.state.invoice!.status, DocumentStatus.draft);
      expect(cubit.state.message, contains('archived'));
      await cubit.close();
    });

    test('void needs a reason and then reverses', () async {
      final d = await f.draft([line('3')]);
      final cubit = buildDetail();
      await cubit.load(d.id);
      await cubit.post();
      await cubit.voidSale('');
      expect(cubit.state.invoice!.status, DocumentStatus.posted);
      expect(cubit.state.message, isNotNull);
      await cubit.voidSale('Entered twice');
      expect(cubit.state.invoice!.status, DocumentStatus.voided);
      await cubit.close();
    });

    test('approval workflow through the cubit', () async {
      f.settings.salesApprovalRequired = true;
      final d = await f.draft([line('3')]);
      final cubit = buildDetail();
      await cubit.load(d.id);
      expect(cubit.state.approvalRequired, isTrue);
      await cubit.submit();
      expect(cubit.state.invoice!.status, DocumentStatus.pendingApproval);
      await cubit.approve();
      expect(cubit.state.invoice!.status, DocumentStatus.approved);
      await cubit.post();
      expect(cubit.state.invoice!.status, DocumentStatus.posted);
      await cubit.close();
    });

    test('cancel marks the draft cancelled', () async {
      final d = await f.draft([line('1')]);
      final cubit = buildDetail();
      await cubit.load(d.id);
      await cubit.cancel();
      expect(cubit.state.invoice!.status, DocumentStatus.cancelled);
      await cubit.close();
    });
  });

  group('SalesFormCubit', () {
    test('loads reference data for a new sale', () async {
      final cubit = buildForm();
      await cubit.load();
      expect(cubit.state.loadStatus, FormLoadStatus.ready);
      expect(cubit.state.customers.single.id, 'c1');
      expect(cubit.state.products.single.id, productId);
      expect(cubit.state.invoiceDate, isNotNull);
      expect(cubit.state.lines, isEmpty);
      await cubit.close();
    });

    test('saveLine rejects invalid input and returns the errors', () async {
      final cubit = buildForm();
      await cubit.load();
      final errors = await cubit.saveLine(line('1.5'));
      expect(errors.keys, contains('quantity'));
      expect(cubit.state.lines, isEmpty);
      await cubit.close();
    });

    test('lines update live totals; edit and remove recalculate', () async {
      final cubit = buildForm();
      await cubit.load();
      expect(await cubit.saveLine(line('2', price: '10')), isEmpty);
      expect(await cubit.saveLine(line('1', price: '5')), isEmpty);
      expect(cubit.state.totals!.total, inr(2500));
      expect(cubit.state.previews.length, 2);

      expect(
        await cubit.saveLine(
          SalesLineInput(
            productId: productId,
            quantity: '2',
            unitPrice: '10',
            discountKind: DiscountKind.percent,
            discountValue: '50',
          ),
          index: 0,
        ),
        isEmpty,
      );
      expect(cubit.state.totals!.total, inr(1500));

      await cubit.removeLine(1);
      expect(cubit.state.lines.length, 1);
      expect(cubit.state.totals!.total, inr(1000));
      await cubit.close();
    });

    test('submit reports field errors', () async {
      final cubit = buildForm();
      await cubit.load();
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.validationError);
      expect(cubit.state.fieldErrors.keys, contains('lines'));
      await cubit.close();
    });

    test('a sale without a customer is saved as a walk-in sale', () async {
      final cubit = buildForm();
      await cubit.load();
      await cubit.saveLine(line('1'));
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(f.sales.items[cubit.state.savedId]!.customerId, isNull);
      cubit.setCustomer('c1');
      expect(cubit.state.customerId, 'c1');
      cubit.setCustomer(null);
      expect(cubit.state.customerId, isNull);
      await cubit.close();
    });

    test('a line above the stock is refused with a quantity error', () async {
      final cubit = buildForm();
      await cubit.load();
      final errors = await cubit.saveLine(line('5000'));
      expect(errors['quantity'], contains('Only 1000'));
      expect(cubit.state.lines, isEmpty);
      expect(await cubit.saveLine(line('600')), isEmpty);
      final second = await cubit.saveLine(line('600'));
      expect(second.containsKey('quantity'), isTrue);
      await cubit.close();
    });

    test('submit saves the draft', () async {
      final cubit = buildForm();
      await cubit.load();
      cubit.setCustomer('c1');
      await cubit.saveLine(line('4', price: '2.50'));
      await cubit.submit(customerReference: 'INV-9', notes: 'Rush');
      expect(cubit.state.submitStatus, SubmitStatus.success);
      final saved = f.sales.items[cubit.state.savedId]!;
      expect(saved.status, DocumentStatus.draft);
      expect(saved.customerReference, 'INV-9');
      expect(saved.totals.total, inr(1000));
      await cubit.close();
    });

    test('editing a draft loads its lines and saves over it', () async {
      final d = await f.draft([line('2', price: '10')]);
      final cubit = buildForm();
      await cubit.load(saleId: d.id);
      expect(cubit.state.customerId, 'c1');
      expect(cubit.state.lines.single.quantity, '2');
      expect(cubit.state.totals!.total, inr(2000));
      await cubit.saveLine(line('5', price: '10'), index: 0);
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(f.sales.items.length, 1);
      expect(f.sales.items[d.id]!.totals.total, inr(5000));
      await cubit.close();
    });

    test('a posted sale cannot be edited', () async {
      final d = await f.draft([line('2')]);
      (await f.post(d.id)).valueOrNull!;
      final cubit = buildForm();
      await cubit.load(saleId: d.id);
      expect(cubit.state.blockedReason, isNotNull);
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.idle);
      await cubit.close();
    });

    test('unknown draft id ends in notFound', () async {
      final cubit = buildForm();
      await cubit.load(saleId: 'nope');
      expect(cubit.state.loadStatus, FormLoadStatus.notFound);
      await cubit.close();
    });

    test('a save failure is reported as a failure', () async {
      final cubit = buildForm();
      await cubit.load();
      cubit.setCustomer('c1');
      await cubit.saveLine(line('1'));
      f.sales.saveFailure = const DatabaseFailure('x');
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.failure);
      expect(cubit.state.message, isNotNull);
      await cubit.close();
    });
  });

  group('CustomerDetailCubit receivable', () {
    CustomerDetailCubit build() => CustomerDetailCubit(
      repository: f.customers,
      archiveCustomer: ArchiveCustomer(repository: f.customers, clock: f.clock),
      restoreCustomer: RestoreCustomer(repository: f.customers, clock: f.clock),
      getReceivable: f.receivable,
    );

    test('shows posted sales and the outstanding amount', () async {
      final posted = (await f.post((await f.draft([line('3')])).id))
          .valueOrNull!;
      expect(posted.totals.total, inr(3000));
      final cubit = build();
      await cubit.load('c1');
      expect(cubit.state.status, DetailStatus.loaded);
      expect(cubit.state.receivable!.sales, inr(3000));
      expect(cubit.state.receivable!.outstanding, inr(3000));
      await cubit.close();
    });

    test('works without the receivable use case', () async {
      final cubit = CustomerDetailCubit(
        repository: f.customers,
        archiveCustomer: ArchiveCustomer(
          repository: f.customers,
          clock: f.clock,
        ),
        restoreCustomer: RestoreCustomer(
          repository: f.customers,
          clock: f.clock,
        ),
      );
      await cubit.load('c1');
      expect(cubit.state.receivable, isNull);
      expect(cubit.state.customer!.name, 'Acme Traders');
      await cubit.close();
    });
  });
}
