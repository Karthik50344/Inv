import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_detail_cubit.dart';
import 'package:inventrix/features/returns/presentation/bloc/return_form_cubit.dart';
import 'package:inventrix/features/returns/presentation/bloc/returns_bloc.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/bloc_test_helper.dart';
import '../../support/return_fakes.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  late ReturnFixture f;
  setUp(() => f = ReturnFixture());

  ReturnFormCubit form() => ReturnFormCubit(
    loader: f.loader,
    methods: f.methods,
    postReturn: f.postReturn,
    ids: f.ids,
  );

  group('ReturnsBloc', () {
    blocTest<ReturnsBloc, ReturnsState>(
      'emits loading then empty when there are no returns',
      build: () => ReturnsBloc(returns: f.returns),
      act: (b) => b.add(const ReturnsStarted()),
      expect: () => [
        isA<ReturnsState>().having((s) => s.status, 'status', ViewStatus.loading),
        isA<ReturnsState>().having((s) => s.status, 'status', ViewStatus.empty),
      ],
    );

    test('lists returns and filters by kind and search', () async {
      final p = await f.stockedProduct(stock: '0', cost: '0');
      final bill = await f.postedPurchase({p.id: '10'});
      await f.postedSale({p.id: '2'});
      final sale = f.sales.items.values.first;
      await f.doReturn(InvoiceKind.sales, sale.id, {sale.lines.first.id: '1'});
      await f.doReturn(InvoiceKind.purchase, bill.id, {bill.lines.first.id: '1'});
      final bloc = ReturnsBloc(returns: f.returns)..add(const ReturnsStarted());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.items.length, 2);
      bloc.add(const ReturnsKindChanged(InvoiceKind.purchase));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.items.single.number, 'PRN-000001');
      bloc.add(const ReturnsKindChanged(null));
      bloc.add(const ReturnsSearchChanged('srn'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.items.single.number, 'SRN-000001');
      await bloc.close();
    });
  });

  group('ReturnDetailCubit', () {
    test('loads a return and reports unknown ids', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '2'});
      final doc = (await f.doReturn(InvoiceKind.sales, sale.id,
              {sale.lines.first.id: '1'}))
          .valueOrNull!;
      final cubit = ReturnDetailCubit(returns: f.returns);
      await cubit.load(InvoiceKind.sales, doc.id);
      expect(cubit.state.status, DetailStatus.loaded);
      expect(cubit.state.document!.number, doc.number);
      await cubit.load(InvoiceKind.sales, 'missing');
      expect(cubit.state.status, DetailStatus.notFound);
      await cubit.close();
    });

    test('InvoiceReturnsCubit sums the returns of an invoice', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '3'});
      final id = sale.lines.first.id;
      await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'});
      await f.doReturn(InvoiceKind.sales, sale.id, {id: '1'});
      final cubit = InvoiceReturnsCubit(returns: f.returns);
      await cubit.load(InvoiceKind.sales, sale.id);
      expect(cubit.state.returns.length, 2);
      expect(cubit.state.returnedTotal, inr(20000));
      await cubit.close();
    });
  });

  group('ReturnFormCubit', () {
    test('loads choices, then previews while typing', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'});
      final cubit = form();
      await cubit.load();
      expect(cubit.state.loadStatus, FormLoadStatus.ready);
      expect(cubit.state.choices.single.id, sale.id);
      await cubit.selectInvoice(sale.id);
      final lineId = sale.lines.first.id;
      cubit.setQuantity(lineId, '1');
      expect(cubit.state.plan!.total, inr(10000));
      expect(cubit.state.maxRefund, inr(0)); // nothing paid yet
      cubit.setQuantity(lineId, '9');
      expect(cubit.state.plan!.lineErrors[lineId], contains('Only 4'));
      cubit.returnEverything();
      expect(cubit.state.plan!.total, inr(40000));
      await cubit.close();
    });

    test('refund maximum follows what was paid', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'});
      await f.receive('400', sale.id);
      final cubit = form();
      await cubit.load(invoiceId: sale.id);
      cubit.setQuantity(sale.lines.first.id, '2');
      expect(cubit.state.maxRefund, inr(20000));
      cubit.refundMaximum();
      expect(cubit.state.refundText, '200.00');
      await cubit.close();
    });

    test('submit posts once and exposes the saved id', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '4'});
      final cubit = form();
      await cubit.load(invoiceId: sale.id);
      cubit.setQuantity(sale.lines.first.id, '1');
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.validationError);
      expect(cubit.state.fieldErrors['reason'], isNotNull);
      cubit.setReason('Faulty');
      await cubit.submit();
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(cubit.state.savedId, isNotNull);
      expect(f.returns.items.length, 1);
      await cubit.close();
    });

    test('field errors name the failing line', () async {
      final p = await f.stockedProduct();
      final sale = await f.postedSale({p.id: '2'});
      final cubit = form();
      await cubit.load(invoiceId: sale.id);
      final id = sale.lines.first.id;
      cubit.setQuantity(id, '5');
      cubit.setReason('x');
      await cubit.submit();
      expect(cubit.state.fieldErrors.keys, contains('line:$id'));
      await cubit.close();
    });

    test('purchase kind lists purchase invoices', () async {
      final p = await f.stockedProduct(stock: '0', cost: '0');
      final bill = await f.postedPurchase({p.id: '5'});
      final cubit = form();
      await cubit.load(kind: InvoiceKind.purchase);
      expect(cubit.state.choices.single.id, bill.id);
      await cubit.setKind(InvoiceKind.sales);
      expect(cubit.state.choices, isEmpty);
      await cubit.close();
    });
  });
}
