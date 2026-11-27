import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_input.dart';
import 'package:inventrix/features/expenses/domain/usecases/manage_expense_categories.dart';
import 'package:inventrix/features/expenses/domain/usecases/post_expense.dart';
import 'package:inventrix/features/expenses/domain/usecases/save_expense_draft.dart';
import 'package:inventrix/features/expenses/presentation/pages/expense_categories_page.dart';
import 'package:inventrix/features/expenses/presentation/pages/expense_detail_page.dart';
import 'package:inventrix/features/expenses/presentation/pages/expense_form_page.dart';
import 'package:inventrix/features/expenses/presentation/pages/expense_report_page.dart';
import 'package:inventrix/features/expenses/presentation/pages/expenses_page.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';

import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

/// Widget tests of the expense screens on the real router, BLoCs and use
/// cases over fake repositories. (Written without a Flutter SDK: not yet
/// executed.)
void main() {
  late TestWiring wiring;
  late String categoryId;

  const base = '/more/expenses';

  setUp(() async {
    wiring = TestWiring();
    wiring.paymentMethods.items['pm-cash'] = PaymentMethod(
      id: 'pm-cash',
      name: 'Cash',
      createdAt: wiring.clock.now(),
    );
    categoryId = (await wiring.locator<CreateExpenseCategory>()(name: 'Rent'))
        .valueOrNull!
        .id;
  });

  Future<String> seedDraft({
    String amount = '1000',
    String description = 'Shop rent',
  }) async => (await wiring.locator<SaveExpenseDraft>()(
    ExpenseDraftInput(
      categoryId: categoryId,
      expenseDate: DateTime.utc(2026, 1, 1),
      description: description,
      amount: amount,
      methodId: 'pm-cash',
    ),
  )).valueOrNull!.id;

  testWidgets('shows an empty state', (tester) async {
    await pumpInventrix(tester, wiring, location: base);
    expect(find.byType(ExpensesPage), findsOneWidget);
    expect(find.text('No expenses yet'), findsOneWidget);
  });

  testWidgets('lists expenses and filters by status', (tester) async {
    final a = await seedDraft();
    final b = await seedDraft(description: 'Parking');
    await wiring.locator<PostExpense>()(b);
    await pumpInventrix(tester, wiring, location: base);
    expect(find.byKey(Key('expense_$a')), findsOneWidget);
    expect(find.byKey(Key('expense_$b')), findsOneWidget);
    expect(find.textContaining('EXP-000001'), findsOneWidget);

    await tapKey(tester, 'filter_posted');
    expect(find.byKey(Key('expense_$a')), findsNothing);
    expect(find.byKey(Key('expense_$b')), findsOneWidget);
    expect(find.byKey(const Key('expenses_posted_total')), findsOneWidget);

    await tapKey(tester, 'filter_all');
    expect(find.byKey(Key('expense_$a')), findsOneWidget);
  });

  testWidgets('the form validates required fields', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/new');
    await tapKey(tester, 'save_expense_draft');
    expect(find.text('Choose a category.'), findsOneWidget);
    expect(find.text('Choose a payment method.'), findsOneWidget);
    expect(find.text('Amount is required.'), findsOneWidget);
    expect(find.text('Description is required.'), findsOneWidget);
  });

  testWidgets('creates and posts an expense from the form', (tester) async {
    await pumpInventrix(tester, wiring, location: base);
    await tapKey(tester, 'add_expense');
    expect(find.byType(ExpenseFormPage), findsOneWidget);

    await enter(tester, 'expense_description', 'March rent');
    await enter(tester, 'expense_amount', '1000');
    expect(find.byKey(const Key('expense_total')), findsOneWidget);

    await tapKey(tester, 'expense_category');
    await tester.tap(find.text('Rent').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'expense_method');
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();

    await tapKey(tester, 'save_and_post_expense');
    expect(find.byType(ExpensesPage), findsOneWidget);
    expect(find.textContaining('EXP-000001'), findsOneWidget);
    expect(find.text('March rent'), findsOneWidget);
  });

  testWidgets('a draft can be saved without posting', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/new');
    await enter(tester, 'expense_description', 'Parking');
    await enter(tester, 'expense_amount', '40');
    await tapKey(tester, 'expense_category');
    await tester.tap(find.text('Rent').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'expense_method');
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'save_expense_draft');
    expect(wiring.expenseRepository.items.values.single.number, isNull);
  });

  testWidgets('detail: post with confirmation, then void with a reason', (
    tester,
  ) async {
    final id = await seedDraft();
    await pumpInventrix(tester, wiring, location: '$base/$id');
    expect(find.byType(ExpenseDetailPage), findsOneWidget);
    expect(find.byKey(const Key('status_draft')), findsOneWidget);

    await tapKey(tester, 'post_expense');
    await tester.tap(find.text('Post').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('status_posted')), findsOneWidget);
    expect(find.text('EXP-000001'), findsWidgets);
    expect(find.byKey(const Key('edit_expense')), findsNothing);

    await tapKey(tester, 'void_expense');
    await enter(tester, 'void_reason_input', 'duplicate');
    await tapKey(tester, 'confirm_void');
    expect(find.byKey(const Key('status_voided')), findsOneWidget);
    expect(find.text('duplicate'), findsOneWidget);
    expect(find.byKey(const Key('void_expense')), findsNothing);
  });

  testWidgets('detail: cancel a draft', (tester) async {
    final id = await seedDraft();
    await pumpInventrix(tester, wiring, location: '$base/$id');
    await tapKey(tester, 'cancel_expense');
    await tester.tap(find.text('Cancel draft').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('status_cancelled')), findsOneWidget);
  });

  testWidgets('detail of an unknown expense shows not found', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/missing');
    expect(find.text('Expense not found'), findsOneWidget);
  });

  testWidgets('editing an unknown draft shows not found', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/missing/edit');
    expect(find.text('Expense not found'), findsOneWidget);
  });

  testWidgets('categories: add, reject duplicate, archive', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/categories');
    expect(find.byType(ExpenseCategoriesPage), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);

    await tapKey(tester, 'add_expense_category');
    await enter(tester, 'expense_category_name', 'rent');
    await tapKey(tester, 'expense_category_save');
    expect(find.textContaining('already exists'), findsOneWidget);

    await enter(tester, 'expense_category_name', 'Utilities');
    await tapKey(tester, 'expense_category_save');
    expect(find.text('Utilities'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<dynamic>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    expect(find.text('Rent'), findsNothing);
  });

  testWidgets('report shows totals and the empty state', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/report');
    expect(find.byType(ExpenseReportPage), findsOneWidget);
    expect(find.text('No expenses in this period'), findsOneWidget);
  });

  testWidgets('report adds up posted expenses by category', (tester) async {
    final a = await seedDraft();
    final b = await seedDraft(amount: '250.50');
    await wiring.locator<PostExpense>()(a);
    await wiring.locator<PostExpense>()(b);
    await seedDraft(amount: '9999'); // a draft: not counted
    await pumpInventrix(tester, wiring, location: '$base/report');
    expect(find.byKey(const Key('report_total')), findsOneWidget);
    expect(find.textContaining('1,250.50'), findsWidgets);
    expect(find.byKey(Key('report_category_$categoryId')), findsOneWidget);
    expect(find.byKey(const Key('report_count')), findsOneWidget);
  });
}
