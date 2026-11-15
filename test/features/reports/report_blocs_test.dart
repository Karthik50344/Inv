import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:inventrix/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:inventrix/features/reports/domain/entities/report_figures.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/entities/report_period.dart';
import 'package:inventrix/features/reports/presentation/bloc/report_bloc.dart';
import 'package:inventrix/features/reports/presentation/bloc/report_event.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/report_fakes.dart';
import 'report_use_cases_test.dart' show ReportFixture;

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  late ReportFixture f;
  setUp(() => f = ReportFixture());

  ReportBloc reportBloc() => ReportBloc(
    buildReport: f.build,
    exportReport: f.export,
    options: f.options,
    clock: f.pay.clock,
  );
  DashboardBloc dashBloc() =>
      DashboardBloc(getDashboard: f.dashboard, clock: f.pay.clock);

  group('ReportBloc', () {
    test('starts with this month and loads the report', () async {
      f.reports.sales = figures(count: 1, net: 100);
      f.reports.salesRowList = [
        DocumentRow(
          id: 'a',
          number: 'INV-1',
          date: DateTime.utc(2026, 3, 2),
          partyName: 'X',
          net: inr(100),
          tax: inr(0),
          total: inr(100),
        ),
      ];
      final bloc = reportBloc()..add(const ReportStarted(ReportKind.sales));
      await settle();
      expect(bloc.state.status, ViewStatus.loaded);
      expect(bloc.state.kind, ReportKind.sales);
      expect(
        bloc.state.filter!.range.from,
        DateTime.utc(2026, 3, 1),
      ); // clock: 10 Mar 2026
      expect(bloc.state.document, isNotNull);
    });
    test('no rows means empty status but the document is kept', () async {
      final bloc = reportBloc()..add(const ReportStarted(ReportKind.sales));
      await settle();
      expect(bloc.state.status, ViewStatus.empty);
      expect(bloc.state.document, isNotNull);
    });
    test('loads filter choices only for reports that use them', () async {
      final a = reportBloc()
        ..add(const ReportStarted(ReportKind.profitability));
      await settle();
      expect(a.state.choices.customers, isEmpty);
      final b = reportBloc()..add(const ReportStarted(ReportKind.payments));
      await settle();
      expect(b.state.choices.customers, hasLength(1));
      expect(b.state.choices.suppliers, hasLength(1));
    });
    test('changing the period reloads with the new range', () async {
      final bloc = reportBloc()..add(const ReportStarted(ReportKind.sales));
      await settle();
      bloc.add(const ReportPeriodChanged(ReportPeriod.lastMonth));
      await settle();
      expect(bloc.state.period, ReportPeriod.lastMonth);
      expect(f.reports.filters.last.range.from, DateTime.utc(2026, 2, 1));
      expect(f.reports.filters.last.range.to, DateTime.utc(2026, 2, 28));
    });
    test(
      'custom period uses the given range, and is ignored without one',
      () async {
        final bloc = reportBloc()..add(const ReportStarted(ReportKind.sales));
        await settle();
        final custom = DateRange(
          from: DateTime.utc(2026, 1, 5),
          to: DateTime.utc(2026, 1, 9),
        );
        bloc.add(ReportPeriodChanged(ReportPeriod.custom, range: custom));
        await settle();
        expect(bloc.state.filter!.range, custom);
        bloc.add(const ReportPeriodChanged(ReportPeriod.custom));
        await settle();
        expect(bloc.state.filter!.range, custom);
      },
    );
    test('changing the filter keeps the range', () async {
      final bloc = reportBloc()..add(const ReportStarted(ReportKind.sales));
      await settle();
      final range = bloc.state.filter!.range;
      bloc.add(
        ReportFilterChanged(bloc.state.filter!.copyWith(customerId: 'c1')),
      );
      await settle();
      expect(f.reports.filters.last.customerId, 'c1');
      expect(bloc.state.filter!.range, range);
    });
    test('a failure shows a user message and keeps no stale status', () async {
      f.reports.failure = const DatabaseFailure('boom');
      final bloc = reportBloc()..add(const ReportStarted(ReportKind.sales));
      await settle();
      expect(bloc.state.status, ViewStatus.failure);
      expect(bloc.state.message, isNotNull);
      f.reports.failure = null;
      bloc.add(const ReportRefreshed());
      await settle();
      expect(bloc.state.status, ViewStatus.empty);
      expect(bloc.state.message, isNull);
    });
    test('export shares the CSV and reports success', () async {
      f.reports.sales = figures(count: 1, net: 100);
      final bloc = reportBloc()..add(const ReportStarted(ReportKind.sales));
      await settle();
      bloc.add(const ReportExportRequested());
      await settle();
      expect(bloc.state.exportStatus, SubmitStatus.success);
      expect(f.exporter.fileName, startsWith('inventrix-sales-'));
    });
    test('export failure is reported', () async {
      f.exporter.failure = const UnexpectedFailure('no');
      final bloc = reportBloc()..add(const ReportStarted(ReportKind.sales));
      await settle();
      bloc.add(const ReportExportRequested());
      await settle();
      expect(bloc.state.exportStatus, SubmitStatus.failure);
      expect(bloc.state.message, isNotNull);
    });
    test('export before a report exists does nothing', () async {
      reportBloc()..add(const ReportExportRequested());
      await settle();
      expect(f.exporter.fileName, isNull);
    });
  });

  group('DashboardBloc', () {
    test('a fresh database is empty', () async {
      final bloc = dashBloc()..add(const DashboardStarted());
      await settle();
      expect(bloc.state.status, ViewStatus.empty);
      expect(bloc.state.period, ReportPeriod.thisMonth);
      expect(bloc.state.snapshot, isNotNull);
    });
    test('loads figures when data exists', () async {
      f.reports.sales = figures(count: 1, net: 500);
      final bloc = dashBloc()..add(const DashboardStarted());
      await settle();
      expect(bloc.state.status, ViewStatus.loaded);
      expect(bloc.state.snapshot!.sales.net, inr(500));
    });
    test('period change reloads for the new range', () async {
      final bloc = dashBloc()..add(const DashboardStarted());
      await settle();
      bloc.add(const DashboardPeriodChanged(ReportPeriod.thisYear));
      await settle();
      expect(bloc.state.range!.from, DateTime.utc(2026, 1, 1));
      expect(f.reports.filters.last.range.from, DateTime.utc(2026, 1, 1));
    });
    test('a custom range is kept on refresh', () async {
      final custom = DateRange(
        from: DateTime.utc(2026, 1, 5),
        to: DateTime.utc(2026, 1, 9),
      );
      final bloc = dashBloc()
        ..add(DashboardPeriodChanged(ReportPeriod.custom, range: custom));
      await settle();
      bloc.add(const DashboardRefreshed());
      await settle();
      expect(bloc.state.range, custom);
    });
    test('preset is re-evaluated against today on refresh', () async {
      final bloc = dashBloc()..add(const DashboardStarted());
      await settle();
      f.pay.clock.advance(const Duration(days: 40)); // into April
      bloc.add(const DashboardRefreshed());
      await settle();
      expect(bloc.state.range!.from, DateTime.utc(2026, 4, 1));
    });
    test('failure keeps the previous snapshot and shows a message', () async {
      f.reports.sales = figures(count: 1, net: 500);
      final bloc = dashBloc()..add(const DashboardStarted());
      await settle();
      f.reports.failure = const DatabaseFailure('boom');
      bloc.add(const DashboardRefreshed());
      await settle();
      expect(bloc.state.status, ViewStatus.failure);
      expect(bloc.state.message, isNotNull);
      expect(bloc.state.snapshot, isNotNull);
    });
  });
}
