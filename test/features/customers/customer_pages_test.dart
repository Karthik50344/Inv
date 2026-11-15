import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/features/customers/domain/usecases/create_customer.dart';
import 'package:inventrix/features/customers/presentation/pages/customer_detail_page.dart';
import 'package:inventrix/features/customers/presentation/pages/customer_form_page.dart';
import 'package:inventrix/features/customers/presentation/pages/customers_page.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:flutter/material.dart';
import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

void main() {
  late TestWiring wiring;

  const base = '/more/customers';

  setUp(() => wiring = TestWiring());

  Future<String> seed(String name, {String phone = ''}) async =>
      (await wiring.locator<CreateCustomer>()(
        PartyDraft(name: name, phone: phone),
      )).valueOrNull!.id;

  testWidgets('shows an empty state', (tester) async {
    await pumpInventrix(tester, wiring, location: base);
    expect(find.byType(CustomersPage), findsOneWidget);
    expect(find.text('No customers yet'), findsOneWidget);
  });

  testWidgets('lists and searches customers', (tester) async {
    await seed('Asha Traders');
    await seed('Bala Stores');
    await pumpInventrix(tester, wiring, location: base);
    expect(find.text('Asha Traders'), findsOneWidget);
    expect(find.text('Bala Stores'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'bala');
    await tester.pumpAndSettle();
    expect(find.text('Asha Traders'), findsNothing);
    expect(find.text('Bala Stores'), findsOneWidget);
  });

  testWidgets('creates a customer through the form', (tester) async {
    await pumpInventrix(tester, wiring, location: base);
    await tapKey(tester, 'add_customer');
    expect(find.byType(CustomerFormPage), findsOneWidget);
    await enter(tester, 'party_name', 'Asha Traders');
    await enter(tester, 'party_phone', '+91 98765 43210');
    await enter(tester, 'party_openingBalance', '250.75');
    await tapKey(tester, 'save_customer');
    expect(find.byType(CustomersPage), findsOneWidget);
    expect(find.text('Asha Traders'), findsOneWidget);
    final saved = wiring.customers.items.values.single;
    expect(saved.openingBalance.minorUnits, 25075);
    expect(saved.phone, '+91 98765 43210');
  });

  testWidgets('client validation blocks an empty name', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/new');
    await tapKey(tester, 'save_customer');
    expect(find.text('Name is required.'), findsOneWidget);
    expect(wiring.customers.items, isEmpty);
  });

  testWidgets('server-side errors appear on the fields', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/new');
    await enter(tester, 'party_name', 'Asha');
    await enter(tester, 'party_email', 'not-an-email');
    await enter(tester, 'party_openingBalance', '1.234');
    await tapKey(tester, 'save_customer');
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.textContaining('decimal places'), findsWidgets);
    expect(wiring.customers.items, isEmpty);
  });

  testWidgets('opens details, edits and archives', (tester) async {
    await seed('Asha Traders');
    await pumpInventrix(tester, wiring, location: base);
    await tester.tap(find.text('Asha Traders'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerDetailPage), findsOneWidget);

    await tapKey(tester, 'edit_customer');
    await enter(tester, 'party_name', 'Asha & Sons');
    await tapKey(tester, 'save_customer');
    expect(find.byType(CustomerDetailPage), findsOneWidget);
    expect(wiring.customers.items.values.single.name, 'Asha & Sons');

    await tapKey(tester, 'toggle_archive_customer');
    await tester.tap(find.text('Archive').last);
    await tester.pumpAndSettle();
    expect(wiring.customers.items.values.single.isArchived, isTrue);
    expect(find.text('Archived'), findsOneWidget);
  });

  testWidgets('an invalid id shows a not-found message', (tester) async {
    await pumpInventrix(tester, wiring, location: '$base/ghost');
    expect(find.text('Customer not found'), findsOneWidget);
    await pumpInventrix(tester, wiring, location: '$base/ghost/edit');
    expect(find.text('Customer not found'), findsOneWidget);
  });

  test('route paths exist for customers', () {
    expect(RoutePaths.customers, base);
  });
}
