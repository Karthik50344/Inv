import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';

import '../../support/report_fakes.dart';
import '../../support/test_locator.dart';
import '../../support/widget_helpers.dart';

/// Widget tests of the dashboard and report screens on the real router,
/// BLoCs and use cases over fake repositories. (Written without a Flutter
/// SDK: not yet executed.)
void main() {
  late TestWiring wiring;

  setUp(() => wiring = TestWiring());

  DocumentRow row() => DocumentRow(
    id: 'a',
    number: 'INV-000001',
    date: DateTime.utc(2026, 1, 3),
    partyName: 'Acme',
    net: inr(100000),
    tax: inr(18000),
    total: inr(118000),
  );

  testWidgets('dashboard shows the welcome state on a fresh database', (
    tester,
  ) async {
    await pumpInventrix(tester, wiring);
    expect(find.text('No data yet'), findsOneWidget);
  });

  testWidgets('dashboard shows period figures and recent sales', (
    tester,
  ) async {
    wiring.reports
      ..sales = figures(count: 1, net: 100000, tax: 18000)
      ..salesRowList = [row()];
    await pumpInventrix(tester, wiring);
    expect(find.text('Net sales'), findsWidgets);
    for (final title in [
      'Sales trend',
      'Where the money went',
      'Expenses by category',
      'Top products',
      'Stock health',
      'Cash and balances',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(title), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text('Recent sales'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recent sales'), findsOneWidget);
    expect(find.textContaining('INV-000001'), findsOneWidget);
    expect(find.byKey(const Key('period_thisMonth')), findsOneWidget);
  });

  testWidgets('the reports list offers every report', (tester) async {
    await pumpInventrix(tester, wiring, location: '/more/reports');
    for (final kind in ReportKind.values) {
      await tester.scrollUntilVisible(
        find.byKey(Key('report_${kind.name}')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(Key('report_${kind.name}')), findsOneWidget);
    }
  });

  testWidgets('the sales report shows figures and exports CSV', (tester) async {
    wiring.reports
      ..sales = figures(count: 1, net: 100000, tax: 18000)
      ..salesRowList = [row()];
    await pumpInventrix(tester, wiring, location: '/more/reports/sales');
    expect(find.text('Sales report'), findsOneWidget);
    expect(find.text('Net sales'), findsWidgets);
    expect(find.text('INV-000001'), findsOneWidget);
    await tapKey(tester, 'report_export');
    expect(wiring.reportExporter.fileName, startsWith('inventrix-sales-'));
  });

  testWidgets('a report without rows says so', (tester) async {
    await pumpInventrix(tester, wiring, location: '/more/reports/sales');
    expect(find.byKey(const Key('report_empty_message')), findsOneWidget);
  });

  testWidgets('an unknown report kind shows the not-found page', (
    tester,
  ) async {
    await pumpInventrix(tester, wiring, location: '/more/reports/nope');
    expect(find.textContaining('not found'), findsWidgets);
  });
}
