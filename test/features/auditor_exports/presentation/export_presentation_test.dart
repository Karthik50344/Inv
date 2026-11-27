import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/export_history_use_cases.dart';
import 'package:inventrix/features/auditor_exports/data/services/zip_export_codec.dart';
import 'package:inventrix/features/auditor_exports/presentation/bloc/export_history_cubit.dart';
import 'package:inventrix/features/auditor_exports/presentation/bloc/export_wizard_cubit.dart';
import 'package:inventrix/features/auditor_exports/presentation/pages/export_wizard_page.dart';
import 'package:inventrix/features/auditor_exports/presentation/support/export_labels.dart';
import 'package:inventrix/features/auditor_exports/presentation/support/export_preset.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../audit/audit_test_support.dart';
import '../export_test_support.dart';

class _Clock implements Clock {
  _Clock(this.value);
  final DateTime value;
  @override
  DateTime now() => value;
}

class _Exporter implements BackupExporter {
  bool completed = true;
  @override
  Future<Result<ExportResult>> export({required String path, required String fileName, required ExportMode mode}) async =>
      Result.success(ExportResult(completed: completed));
}

void main() {
  ExportWizardCubit wizard(ExportHarness h, {DateTime? now, ExportPreset? preset}) => ExportWizardCubit(
    generate: h.useCase,
    clock: _Clock(now ?? DateTime.utc(2026, 11, 22)),
    preset: preset,
  );

  group('ExportWizardCubit', () {
    test('starts on the current financial year with everything but invoice PDFs, as a ZIP', () {
      final c = wizard(ExportHarness());
      expect(c.state.step, ExportStep.period);
      expect(c.state.period!.label, 'FY 2026-27');
      expect(c.state.format, ExportFormat.zip);
      expect(c.state.datasets, contains(ExportDataset.auditTrail));
      expect(c.state.datasets, isNot(contains(ExportDataset.invoicePdfs)));
    });

    test('before April the current financial year started last year', () {
      final c = wizard(ExportHarness(), now: DateTime.utc(2027, 2, 10));
      expect(c.state.fyStartYear, 2026);
    });

    test('the year list offers five years, newest first', () {
      expect(wizard(ExportHarness()).fyYears, [2026, 2025, 2024, 2023, 2022]);
    });

    test('a custom range must be complete and in order before moving on', () {
      final c = wizard(ExportHarness())..setPeriodKind(ExportPeriodKind.custom);
      c.next();
      expect(c.state.step, ExportStep.period);
      expect(c.state.periodError, isNotNull);
      c.setCustomRange(DateTime.utc(2026, 7), DateTime.utc(2026, 6));
      c.next();
      expect(c.state.periodError, contains('must not be after'));
      c.setCustomRange(DateTime.utc(2026, 6), DateTime.utc(2026, 7));
      expect(c.state.periodError, isNull);
      c.next();
      expect(c.state.step, ExportStep.content);
    });

    test('at least one item must be chosen', () {
      final c = wizard(ExportHarness())..next()..selectNone();
      c.next();
      expect(c.state.step, ExportStep.content);
      expect(c.state.contentError, isNotNull);
      c.toggleDataset(ExportDataset.products, selected: true);
      expect(c.state.contentError, isNull);
      c.next();
      expect(c.state.step, ExportStep.format);
    });

    test('back goes one step and the first step has nothing before it', () {
      final c = wizard(ExportHarness())..next()..next();
      expect(c.state.step, ExportStep.format);
      c.back();
      expect(c.state.step, ExportStep.content);
      c..back()..back();
      expect(c.state.step, ExportStep.period);
    });

    test('the request carries the choices', () {
      final c = wizard(ExportHarness())
        ..selectNone()
        ..toggleDataset(ExportDataset.products, selected: true)
        ..setFormat(ExportFormat.xlsx)
        ..setName('  Year end  ');
      final r = c.state.request!;
      expect(r.datasets, {ExportDataset.products});
      expect(r.format, ExportFormat.xlsx);
      expect(r.name, 'Year end');
      expect(r.period.label, 'FY 2026-27');
    });

    test('ticking and unticking items', () {
      final c = wizard(ExportHarness())..selectNone()..selectAll();
      expect(c.state.datasets.length, ExportDataset.values.length - 1);
      c.toggleDataset(ExportDataset.customers, selected: false);
      expect(c.state.datasets, isNot(contains(ExportDataset.customers)));
    });

    test('a preset from the audit log picks the audit trail and its dates', () {
      final c = wizard(
        ExportHarness(),
        preset: ExportPreset.auditTrail(from: DateTime.utc(2026, 5), to: DateTime.utc(2026, 5, 31)),
      );
      expect(c.state.datasets, {ExportDataset.auditTrail});
      expect(c.state.periodKind, ExportPeriodKind.custom);
      expect(c.state.period!.fromText, '2026-05-01');
    });

    test('opening the wizard from the audit log (preset without dates) works and the sets stay editable', () {
      final c = wizard(ExportHarness(), preset: ExportPreset.auditTrail());
      expect(c.state.datasets, {ExportDataset.auditTrail});
      expect(c.state.periodKind, ExportPeriodKind.financialYear);
      c.toggleDataset(ExportDataset.products, selected: true);
      expect(c.state.datasets, {ExportDataset.auditTrail, ExportDataset.products});
      c.selectAll();
      expect(c.state.datasets, isNot(contains(ExportDataset.invoicePdfs)));
    });

    test('creating the export gives a verified record', () async {
      final h = ExportHarness();
      final c = wizard(h)..selectNone()..toggleDataset(ExportDataset.products, selected: true);
      await c.submit();
      expect(c.state.submitting, isFalse);
      expect(c.state.error, isNull);
      expect(c.state.record!.integrityStatus, 'verified');
      expect(h.history.records, hasLength(1));
    });

    test('a failure is shown as a message and can be retried', () async {
      final h = ExportHarness();
      h.source.failure = const DatabaseFailure('The data is locked.');
      final c = wizard(h);
      await c.submit();
      expect(c.state.error, 'The data is locked.');
      expect(c.state.record, isNull);
      h.source.failure = null;
      await c.submit();
      expect(c.state.record, isNotNull);
    });

    test('submitting twice at once creates one export', () async {
      final h = ExportHarness();
      final c = wizard(h);
      await Future.wait([c.submit(), c.submit()]);
      expect(h.history.records, hasLength(1));
    });

    test('nothing happens while an invalid request is submitted', () async {
      final h = ExportHarness();
      final c = wizard(h)..selectNone();
      await c.submit();
      expect(h.history.records, isEmpty);
    });
  });

  group('ExportListCubit', () {
    late ExportHarness h;
    late _Exporter exporter;

    ExportListCubit cubit({String? only}) {
      final clock = StepClock(DateTime.utc(2026, 8));
      final recorder = recorderFor(h.audit);
      return ExportListCubit(
        list: ListExportHistory(h.history),
        history: h.history,
        verify: VerifyExportFile(history: h.history, store: h.store, zip: const ArchiveExportZipCodec(), hasher: byteHasher, clock: clock),
        share: ShareExportFile(history: h.history, store: h.store, exporter: exporter, recorder: recorder),
        deleteFile: DeleteExportFile(history: h.history, store: h.store, recorder: recorder, clock: clock),
        only: only,
      );
    }

    Future<String> make() async {
      final r = await h.useCase(
        ExportRequest(period: const ExportPeriod.all(), datasets: {ExportDataset.products}, format: ExportFormat.zip),
      );
      return r.valueOrNull!.id;
    }

    setUp(() {
      h = ExportHarness();
      exporter = _Exporter();
    });

    test('an empty history is an empty state', () async {
      final c = cubit();
      await c.load();
      expect(c.state.status, ViewStatus.empty);
    });

    test('lists exports and loads a single one for the detail screen', () async {
      final id = await make();
      final all = cubit();
      await all.load();
      expect(all.state.records.single.id, id);
      final one = cubit(only: id);
      await one.load();
      expect(one.state.status, ViewStatus.loaded);
      final missing = cubit(only: 'nope');
      await missing.load();
      expect(missing.state.status, ViewStatus.failure);
    });

    test('checking a good file says so, a changed file says not to rely on it', () async {
      final id = await make();
      final c = cubit();
      await c.load();
      await c.verify(id);
      expect(c.state.message, contains('exactly as it was'));
      expect(c.state.records.single.integrityStatus, 'verified');
      final name = c.state.records.single.fileName;
      h.store.files[name] = bytes('tampered');
      await c.verify(id);
      expect(c.state.message, contains('Do not rely on it'));
      expect(c.state.records.single.integrityStatus, 'failed');
    });

    test('each message can be shown even if it repeats', () async {
      final id = await make();
      final c = cubit();
      await c.load();
      await c.verify(id);
      final first = c.state.messageSerial;
      await c.verify(id);
      expect(c.state.messageSerial, greaterThan(first));
    });

    test('sharing reports success, and a cancelled share reports nothing', () async {
      final id = await make();
      final c = cubit();
      await c.load();
      await c.share(id, ExportMode.share);
      expect(c.state.message, 'Shared.');
      exporter.completed = false;
      await c.share(id, ExportMode.saveToDevice);
      expect(c.state.message, isNull);
      expect(c.state.busyId, isNull);
    });

    test('removing the file updates the record and keeps it listed', () async {
      final id = await make();
      final c = cubit();
      await c.load();
      await c.deleteFile(id);
      expect(c.state.records.single.hasFile, isFalse);
      expect(c.state.message, contains('removed'));
      expect(h.audit.events.where((e) => e.eventType == 'data_export.file_deleted'), hasLength(1));
    });

    test('labels', () {
      expect(ExportLabels.size(512), '512 B');
      expect(ExportLabels.size(2048), '2.0 KB');
      expect(ExportLabels.size(3 * 1024 * 1024), '3.0 MB');
      expect(ExportLabels.chain('broken'), contains('problem'));
      for (final d in ExportDataset.values) {
        expect(ExportLabels.datasetHelp(d), isNotEmpty);
      }
      for (final f in ExportFormat.values) {
        expect(ExportLabels.formatHelp(f), isNotEmpty);
      }
    });
  });

  group('wizard page', () {
    for (final theme in {'light': AppTheme.light(), 'dark': AppTheme.dark()}.entries) {
      testWidgets('walks through the four steps in ${theme.key}', (tester) async {
        tester.view
          ..physicalSize = const Size(420, 900)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = ExportHarness();
        final cubit = wizard(h);
        addTearDown(cubit.close);
        await tester.pumpWidget(
          MaterialApp(theme: theme.value, home: BlocProvider.value(value: cubit, child: const ExportWizardPage())),
        );
        expect(find.text('Step 1 of 4: Period'), findsOneWidget);
        expect(find.text('FY 2026-27'), findsWidgets);

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Step 2 of 4: Content'), findsOneWidget);
        expect(find.text('Sales invoices'), findsOneWidget);

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Step 3 of 4: File type'), findsOneWidget);
        expect(find.text('Complete ZIP package'), findsOneWidget);

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Create export'), findsWidgets);
        expect(find.textContaining('not digitally signed'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('choosing nothing shows a message and stays on the step', (tester) async {
      tester.view
        ..physicalSize = const Size(420, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final cubit = wizard(ExportHarness())..next()..selectNone();
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: BlocProvider.value(value: cubit, child: const ExportWizardPage())),
      );
      await tester.tap(find.text('Next'));
      await tester.pump();
      expect(find.text('Choose at least one thing to include.'), findsOneWidget);
      expect(find.text('Step 2 of 4: Content'), findsOneWidget);
    });
  });
}
