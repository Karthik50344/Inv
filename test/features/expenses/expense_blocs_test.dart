import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_filter.dart';
import 'package:inventrix/features/expenses/domain/services/expense_period.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_categories_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_detail_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_form_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expense_report_cubit.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:inventrix/features/expenses/presentation/bloc/expenses_event.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/expense_fakes.dart';

Money inr(int minor) =>
    Money.fromMinor(minor, currencyCode: 'INR', decimalPlaces: 2);

void main() {
  late ExpenseFixture f;

  setUp(() => f = ExpenseFixture());

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  ExpensesBloc listBloc() => ExpensesBloc(
    expenses: f.expenses,
    categories: f.categories,
    settings: f.settings,
  );

  ExpenseFormCubit formCubit() => ExpenseFormCubit(
    expenses: f.expenses,
    categories: f.categories,
    methods: f.methods,
    taxRates: f.taxRates,
    settings: f.settings,
    saveDraft: f.saveDraft,
    postExpense: f.post,
    clock: f.clock,
  );

  ExpenseDetailCubit detailCubit() => ExpenseDetailCubit(
    expenses: f.expenses,
    post: f.post,
    cancel: f.cancel,
    voidExpense: f.voidExpense,
    addAttachment: f.addAttachment,
    removeAttachment: f.removeAttachment,
  );

  group('ExpensesBloc', () {
    test('initial state', () {
      expect(listBloc().state.status, ViewStatus.initial);
    });

    test('empty list', () async {
      final bloc = listBloc()..add(const ExpensesStarted());
      await settle();
      expect(bloc.state.status, ViewStatus.empty);
      expect(bloc.state.postedTotal, inr(0));
      await bloc.close();
    });

    test('loads items and sums only posted expenses', () async {
      await f.posted();
      await f.posted(with_: f.input(amount: '250.50'));
      await f.draft(with_: f.input(amount: '9999'));
      final bloc = listBloc()..add(const ExpensesStarted());
      await settle();
      expect(bloc.state.status, ViewStatus.loaded);
      expect(bloc.state.items, hasLength(3));
      expect(bloc.state.postedTotal, inr(125050));
      expect(bloc.state.categories, hasLength(1));
      await bloc.close();
    });

    test('search, status, category and range filters', () async {
      f.addCategory(id: 'cat-util', name: 'Utilities');
      await f.posted(with_: f.input(description: 'March rent'));
      await f.posted(
        with_: f.input(
          description: 'Electricity',
          categoryId: 'cat-util',
          date: DateTime.utc(2026, 2, 3),
        ),
      );
      await f.draft(with_: f.input(description: 'Maybe later'));
      final bloc = listBloc()..add(const ExpensesStarted());
      await settle();

      bloc.add(const ExpensesSearchChanged('electric'));
      await settle();
      expect(bloc.state.items.single.description, 'Electricity');
      expect(bloc.state.filter.query, 'electric');

      bloc.add(const ExpensesSearchChanged(''));
      bloc.add(const ExpensesStatusChanged(DocumentStatus.draft));
      await settle();
      expect(bloc.state.items.single.description, 'Maybe later');

      bloc.add(const ExpensesStatusChanged(null));
      bloc.add(const ExpensesCategoryChanged('cat-util'));
      await settle();
      expect(bloc.state.items.single.description, 'Electricity');

      bloc.add(const ExpensesCategoryChanged(null));
      bloc.add(
        ExpensesRangeChanged(
          from: DateTime.utc(2026, 3),
          to: DateTime.utc(2026, 3, 31),
        ),
      );
      await settle();
      expect(bloc.state.items, hasLength(2));
      expect(bloc.state.filter.isActive, isTrue);

      bloc.add(const ExpensesRangeChanged());
      await settle();
      expect(bloc.state.items, hasLength(3));
      expect(bloc.state.filter, const ExpenseFilter());
      await bloc.close();
    });
  });

  group('ExpenseFormCubit', () {
    test('loads choices and defaults the date to today', () async {
      f.addTaxRate();
      final cubit = formCubit();
      await cubit.load();
      expect(cubit.state.loadStatus, FormLoadStatus.ready);
      expect(cubit.state.categories, hasLength(1));
      expect(cubit.state.methods, hasLength(1));
      expect(cubit.state.taxRates, hasLength(1));
      expect(cubit.state.expenseDate, isNotNull);
      expect(cubit.state.blockedReason, isNull);
      await cubit.close();
    });

    test('blocked without categories or payment methods', () async {
      f.categories.items.clear();
      var cubit = formCubit();
      await cubit.load();
      expect(cubit.state.blockedReason, contains('category'));
      await cubit.close();
      f.addCategory();
      f.methods.items.clear();
      cubit = formCubit();
      await cubit.load();
      expect(cubit.state.blockedReason, contains('payment method'));
      await cubit.close();
    });

    test('live preview follows amount, tax and inclusive switch', () async {
      f.addTaxRate();
      final cubit = formCubit();
      await cubit.load();
      expect(cubit.state.preview, isNull);
      cubit.setAmount('1000');
      expect(cubit.state.preview!.total, inr(100000));
      cubit.setTaxRate('gst18');
      expect(cubit.state.preview!.total, inr(118000));
      expect(cubit.state.preview!.tax, inr(18000));
      cubit.setIncludesTax(value: true);
      expect(cubit.state.preview!.net, inr(84746));
      expect(cubit.state.preview!.total, inr(100000));
      cubit.setAmount('abc');
      expect(cubit.state.preview, isNull);
      cubit.setAmount('0');
      expect(cubit.state.preview, isNull);
      cubit.setAmount('1000');
      cubit.setTaxRate(null);
      expect(cubit.state.preview!.tax, inr(0));
      await cubit.close();
    });

    test('exempt tax previews no tax', () async {
      f.addTaxRate(id: 'ex', name: 'Exempt', bp: 0, exempt: true);
      final cubit = formCubit();
      await cubit.load();
      cubit
        ..setAmount('100')
        ..setTaxRate('ex');
      expect(cubit.state.preview!.tax, inr(0));
      await cubit.close();
    });

    test('submit shows field errors and does not save', () async {
      final cubit = formCubit();
      await cubit.load();
      await cubit.submit(description: '');
      expect(cubit.state.submitStatus, SubmitStatus.validationError);
      expect(cubit.state.fieldErrors['description'], isNotNull);
      expect(cubit.state.fieldErrors['categoryId'], isNotNull);
      expect(cubit.state.fieldErrors['amount'], isNotNull);
      expect(f.expenses.items, isEmpty);
      await cubit.close();
    });

    test('submit saves a draft', () async {
      final cubit = formCubit();
      await cubit.load();
      cubit
        ..setCategory('cat-rent')
        ..setMethod('pm-cash')
        ..setAmount('300');
      await cubit.submit(description: 'Parking', payee: 'City');
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(cubit.state.posted, isFalse);
      final saved = f.expenses.items[cubit.state.savedId]!;
      expect(saved.status, DocumentStatus.draft);
      expect(saved.payee, 'City');
      await cubit.close();
    });

    test('submit with post saves and posts', () async {
      final cubit = formCubit();
      await cubit.load();
      cubit
        ..setCategory('cat-rent')
        ..setMethod('pm-cash')
        ..setAmount('300');
      await cubit.submit(description: 'Parking', post: true);
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(cubit.state.posted, isTrue);
      expect(f.expenses.items[cubit.state.savedId]!.number, 'EXP-000001');
      await cubit.close();
    });

    test('post refused after saving keeps the draft and explains', () async {
      final cubit = formCubit();
      await cubit.load();
      cubit
        ..setCategory('cat-rent')
        ..setMethod('pm-cash')
        ..setAmount('300');
      f.expenses.postFailure = const DatabaseFailure('disk full');
      await cubit.submit(description: 'Parking', post: true);
      expect(cubit.state.submitStatus, SubmitStatus.success);
      expect(cubit.state.posted, isFalse);
      expect(cubit.state.message, contains('Saved as a draft'));
      expect(
        f.expenses.items[cubit.state.savedId]!.status,
        DocumentStatus.draft,
      );
      await cubit.close();
    });

    test(
      'a category archived since the draft was saved must be re-chosen',
      () async {
        final d = await f.draft();
        f.categories.items['cat-rent'] = f.categories.items['cat-rent']!
            .archived(f.clock.now());
        f.addCategory(id: 'cat-other', name: 'Other');
        final cubit = formCubit();
        await cubit.load(expenseId: d.id);
        expect(cubit.state.categoryId, isNull);
        await cubit.submit(description: 'Shop rent');
        expect(cubit.state.fieldErrors['categoryId'], isNotNull);
        cubit.setCategory('cat-other');
        await cubit.submit(description: 'Shop rent');
        expect(cubit.state.submitStatus, SubmitStatus.success);
        await cubit.close();
      },
    );

    test(
      'editing loads the draft; inclusive amount shows the entered total',
      () async {
        f.addTaxRate();
        final d = await f.draft(
          with_: f.input(amount: '1180', taxRateId: 'gst18', includesTax: true),
        );
        final cubit = formCubit();
        await cubit.load(expenseId: d.id);
        expect(cubit.state.loadStatus, FormLoadStatus.ready);
        expect(cubit.state.amount, '1180.00');
        expect(cubit.state.amountIncludesTax, isTrue);
        expect(cubit.state.taxRateId, 'gst18');
        expect(cubit.state.description, 'Shop rent');
        expect(cubit.state.preview!.total, inr(118000));
        await cubit.submit(description: 'Shop rent (edited)');
        expect(f.expenses.items[d.id]!.description, 'Shop rent (edited)');
        expect(f.expenses.items, hasLength(1));
        await cubit.close();
      },
    );

    test('a posted expense is blocked; unknown id is not found', () async {
      final p = await f.posted();
      var cubit = formCubit();
      await cubit.load(expenseId: p.id);
      expect(cubit.state.blockedReason, isNotNull);
      await cubit.close();
      cubit = formCubit();
      await cubit.load(expenseId: 'nope');
      expect(cubit.state.loadStatus, FormLoadStatus.notFound);
      await cubit.close();
    });
  });

  group('ExpenseDetailCubit', () {
    test('loads, not found', () async {
      final d = await f.draft();
      var cubit = detailCubit();
      await cubit.load(d.id);
      expect(cubit.state.status, DetailStatus.loaded);
      expect(cubit.state.expense!.id, d.id);
      await cubit.close();
      cubit = detailCubit();
      await cubit.load('missing');
      expect(cubit.state.status, DetailStatus.notFound);
      await cubit.close();
    });

    test('post, void and messages', () async {
      final d = await f.draft();
      final cubit = detailCubit();
      await cubit.load(d.id);
      await cubit.post();
      expect(cubit.state.expense!.status, DocumentStatus.posted);
      expect(cubit.state.message, 'Posted.');
      expect(cubit.state.busy, isFalse);
      await cubit.post();
      expect(cubit.state.message, contains('already posted'));
      await cubit.voidExpense('  ');
      expect(cubit.state.expense!.status, DocumentStatus.posted);
      await cubit.voidExpense('mistake');
      expect(cubit.state.expense!.status, DocumentStatus.voided);
      expect(cubit.state.expense!.voidReason, 'mistake');
      await cubit.close();
    });

    test('cancel a draft', () async {
      final d = await f.draft();
      final cubit = detailCubit();
      await cubit.load(d.id);
      await cubit.cancel();
      expect(cubit.state.expense!.status, DocumentStatus.cancelled);
      await cubit.close();
    });

    test('attach and remove', () async {
      final d = await f.draft();
      final cubit = detailCubit();
      await cubit.load(d.id);
      await cubit.attach('/tmp/r.png');
      expect(cubit.state.expense!.attachments, hasLength(1));
      await cubit.removeAttachment(cubit.state.expense!.attachments.single.id);
      expect(cubit.state.expense!.attachments, isEmpty);
      await cubit.attach('/tmp/r2.png');
      await cubit.post();
      await cubit.removeAttachment(cubit.state.expense!.attachments.single.id);
      expect(cubit.state.message, contains('evidence'));
      expect(cubit.state.expense!.attachments, hasLength(1));
      await cubit.close();
    });
  });

  group('ExpenseCategoriesCubit', () {
    ExpenseCategoriesCubit cubit() => ExpenseCategoriesCubit(
      categories: f.categories,
      createCategory: f.createCategory,
      updateCategory: f.updateCategory,
      setArchived: f.setCategoryArchived,
    );

    test('load, create, duplicate, archive, restore, search', () async {
      final c = cubit();
      await c.load();
      expect(c.state.status, ViewStatus.loaded);
      expect((await c.create('Utilities', null)).isSuccess, isTrue);
      expect(c.state.categories, hasLength(2));
      expect((await c.create('utilities', null)).isFailure, isTrue);
      expect(c.state.categories, hasLength(2));
      await c.archive('cat-rent');
      expect(c.state.categories, hasLength(1));
      await c.setIncludeArchived(value: true);
      expect(c.state.categories, hasLength(2));
      await c.restore('cat-rent');
      await c.search('util');
      expect(c.state.categories.single.name, 'Utilities');
      await c.search('zzz');
      expect(c.state.status, ViewStatus.empty);
      await c.close();
    });

    test('update renames', () async {
      final c = cubit();
      await c.load();
      final r = await c.update('cat-rent', 'Premises', 'Shop');
      expect(r.valueOrNull!.description, 'Shop');
      expect(c.state.categories.single.name, 'Premises');
      await c.close();
    });
  });

  group('ExpenseReportCubit', () {
    ExpenseReportCubit cubit() => ExpenseReportCubit(
      expenses: f.expenses,
      categories: f.categories,
      clock: f.clock,
    );

    test('loads this month and shows totals', () async {
      await f.posted();
      await f.posted(
        with_: f.input(amount: '500', date: DateTime.utc(2026, 3, 2)),
      );
      final c = cubit();
      await c.load();
      expect(c.state.period, ExpensePeriod.thisMonth);
      expect(c.state.from, DateTime.utc(2026, 3));
      expect(c.state.status, ViewStatus.loaded);
      expect(c.state.report!.total, inr(150000));
      expect(c.state.report!.count, 2);
      await c.close();
    });

    test('empty period', () async {
      final c = cubit();
      await c.load();
      expect(c.state.status, ViewStatus.empty);
      await c.close();
    });

    test(
      'periods, custom range (swapped when reversed) and category',
      () async {
        f.addCategory(id: 'cat-util', name: 'Utilities');
        await f.posted(with_: f.input(date: DateTime.utc(2026, 2, 10)));
        await f.posted(
          with_: f.input(
            categoryId: 'cat-util',
            amount: '40',
            date: DateTime.utc(2026, 3, 5),
          ),
        );
        final c = cubit();
        await c.load();
        expect(c.state.report!.total, inr(4000));
        await c.setPeriod(ExpensePeriod.lastMonth);
        expect(c.state.report!.total, inr(100000));
        await c.setCustomRange(
          DateTime.utc(2026, 3, 31),
          DateTime.utc(2026, 2),
        );
        expect(c.state.period, ExpensePeriod.custom);
        expect(c.state.from, DateTime.utc(2026, 2));
        expect(c.state.report!.total, inr(104000));
        await c.setCategory('cat-util');
        expect(c.state.report!.total, inr(4000));
        await c.setCategory(null);
        expect(c.state.report!.count, 2);
        await c.close();
      },
    );
  });
}
