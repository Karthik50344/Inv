import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_input.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_bloc.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_detail_cubit.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_event.dart';
import 'package:inventrix/features/purchases/presentation/bloc/purchase_form_cubit.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/discount.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/bloc_test_helper.dart';
import '../../support/purchase_fakes.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  late PurchaseFixture f;
  late String productId;

  setUp(() async {
    f = PurchaseFixture();
    productId = (await f.addProduct(purchase: '10')).id;
  });

  PurchaseLineInput line(String qty, {String price = ''}) =>
      PurchaseLineInput(productId: productId, quantity: qty, unitPrice: price);

  PurchaseBloc buildList() =>
      PurchaseBloc(purchases: f.purchases, settings: f.settings);

  PurchaseDetailCubit buildDetail() => PurchaseDetailCubit(
    purchases: f.purchases,
    settings: f.settings,
    transition: f.transition,
    post: f.post,
    voidPurchase: f.voidPurchase,
  );

  PurchaseFormCubit buildForm() => PurchaseFormCubit(
    purchases: f.purchases,
    suppliers: f.suppliers,
    products: f.products,
    units: f.units,
    settings: f.settings,
    lineBuilder: f.lineBuilder,
    saveDraft: f.saveDraft,
  );

  group('PurchaseBloc', () {
    test('starts initial', () {
      expect(buildList().state.status, ViewStatus.initial);
    });

    blocTest<PurchaseBloc, PurchaseState>(
      'empty when there are no purchases',
      build: buildList,
      act: (b) => b.add(const PurchasesStarted()),
      verify: (b) {
        expect(b.state.status, ViewStatus.empty);
        expect(b.state.items, isEmpty);
      },
    );

    test('loads purchases, searches and filters by status', () async {
      final a = await f.draft([line('1')]);
      final b = await f.draft([line('2')]);
      (await f.post(b.id)).valueOrNull!;
      final bloc = buildList()..add(const PurchasesStarted());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ViewStatus.loaded);
      expect(bloc.state.items.length, 2);

      bloc.add(const PurchasesStatusChanged(DocumentStatus.posted));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items.single.id, b.id);

      bloc.add(const PurchasesStatusChanged(null));
      bloc.add(const PurchasesSearchChanged('PUR-000001'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items.single.id, b.id);

      bloc.add(const PurchasesSearchChanged('zzz'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.status, ViewStatus.empty);
      expect(a.id, isNotEmpty);
      await bloc.close();
    });

    test('toggling approval persists the setting', () async {
      final bloc = buildList()
        ..add(const PurchasesApprovalToggled(required: true));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(f.settings.purchaseApprovalRequired, isTrue);
      expect(bloc.state.approvalRequired, isTrue);
      await bloc.close();
    });
  });

  group('PurchaseDetailCubit', () {
    test('loads a purchase', () async {
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
      expect(cubit.state.message, 'Posted. Stock has been updated.');
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
      await cubit.voidPurchase('');
      expect(cubit.state.invoice!.status, DocumentStatus.posted);
      expect(cubit.state.message, isNotNull);
      await cubit.voidPurchase('Entered twice');
      expect(cubit.state.invoice!.status, DocumentStatus.voided);
      await cubit.close();
    });

    test('approval workflow through the cubit', () async {
      f.settings.purchaseApprovalRequired = true;
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

  group('PurchaseFormCubit', () {
    test('loads reference data for a new purchase', () async {
      final cubit = buildForm();
      await cubit.load();
      expect(cubit.state.loadStatus, FormLoadStatus.ready);
      expect(cubit.state.suppliers.single.id, 's1');
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
          PurchaseLineInput(
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
      expect(
        cubit.state.fieldErrors.keys,
        containsAll(['supplierId', 'lines']),
      );
      await cubit.close();
    });

    test('submit saves the draft', () async {
      final cubit = buildForm();
      await cubit.load();
      cubit.setSupplier('s1');
      await cubit.saveLine(line('4', price: '2.50'));
      await cubit.submit(supplierReference: 'INV-9', notes: 'Rush');
      expect(cubit.state.submitStatus, SubmitStatus.success);
      final saved = f.purchases.items[cubit.state.savedId]!;
      expect(saved.status, DocumentStatus.draft);
      expect(saved.supplierReference, 'INV-9');
      expect(saved.totals.total, inr(1000));
      await cubit.close();
    });

    test('editing a draft loads its lines and saves over it', () async {
      final d = await f.draft([line('2', price: '10')]);
      final cubit = buildForm();
      await cubit.load(purchaseId: d.id);
      expect(cubit.state.supplierId, 's1');
      expect(cubit.state.lines.single.quantity, '2');
      expect(cubit.state.totals!.total, inr(2000));
      await cubit.saveLine(line('5', price: '10'), index: 0);
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(f.purchases.items.length, 1);
      expect(f.purchases.items[d.id]!.totals.total, inr(5000));
      await cubit.close();
    });

    test('a posted purchase cannot be edited', () async {
      final d = await f.draft([line('2')]);
      (await f.post(d.id)).valueOrNull!;
      final cubit = buildForm();
      await cubit.load(purchaseId: d.id);
      expect(cubit.state.blockedReason, isNotNull);
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.idle);
      await cubit.close();
    });

    test('unknown draft id ends in notFound', () async {
      final cubit = buildForm();
      await cubit.load(purchaseId: 'nope');
      expect(cubit.state.loadStatus, FormLoadStatus.notFound);
      await cubit.close();
    });

    test('a save failure is reported as a failure', () async {
      final cubit = buildForm();
      await cubit.load();
      cubit.setSupplier('s1');
      await cubit.saveLine(line('1'));
      f.purchases.saveFailure = const DatabaseFailure('x');
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.failure);
      expect(cubit.state.message, isNotNull);
      await cubit.close();
    });
  });
}
