import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/auditor_exports/data/services/zip_export_codec.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/export_history_use_cases.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';

import '../audit/audit_test_support.dart';
import 'export_test_support.dart';

class _Exporter implements BackupExporter {
  final List<(String, String, ExportMode)> calls = [];
  bool completed = true;

  @override
  Future<Result<ExportResult>> export({
    required String path,
    required String fileName,
    required ExportMode mode,
  }) async {
    calls.add((path, fileName, mode));
    return Result.success(ExportResult(completed: completed));
  }
}

void main() {
  late ExportHarness h;
  late String id;
  late String fileName;

  setUp(() async {
    h = ExportHarness();
    final record = (await h.useCase(
      ExportRequest(
        period: const ExportPeriod.all(),
        datasets: {ExportDataset.products},
        format: ExportFormat.zip,
      ),
    )).valueOrNull!;
    id = record.id;
    fileName = record.fileName;
  });

  VerifyExportFile verify() => VerifyExportFile(
    history: h.history,
    store: h.store,
    zip: const ArchiveExportZipCodec(),
    hasher: byteHasher,
    clock: StepClock(DateTime.utc(2026, 8)),
  );

  test('lists past exports, newest first', () async {
    final list = (await ListExportHistory(h.history)()).valueOrNull!;
    expect(list.single.id, id);
  });

  test('an untouched file verifies again', () async {
    expect((await verify()(id)).valueOrNull, 'verified');
    expect(h.history.records.single.verifiedAt, DateTime.utc(2026, 8));
  });

  test('a file changed after export fails verification', () async {
    final changed = Uint8List.fromList(h.store.files[fileName]!);
    changed[changed.length ~/ 2] ^= 0xFF;
    h.store.files[fileName] = changed;
    expect((await verify()(id)).valueOrNull, 'failed');
    expect(h.history.records.single.integrityStatus, 'failed');
  });

  test('a removed file fails verification', () async {
    h.store.files.remove(fileName);
    expect((await verify()(id)).valueOrNull, 'failed');
  });

  test('an unknown export is reported', () async {
    expect((await verify()('nope')).isFailure, isTrue);
  });

  test('sharing hands the file to the system dialog and records it', () async {
    final exporter = _Exporter();
    final share = ShareExportFile(
      history: h.history,
      store: h.store,
      exporter: exporter,
      recorder: recorderFor(h.audit),
    );
    final r = await share(id, ExportMode.share);
    expect(r.isSuccess, isTrue);
    expect(exporter.calls.single.$1, '/exports/$fileName');
    expect(exporter.calls.single.$3, ExportMode.share);
    expect(h.audit.events.where((e) => e.eventType == 'data_export.shared'), hasLength(1));
  });

  test('a cancelled share is not recorded as shared', () async {
    final exporter = _Exporter()..completed = false;
    await ShareExportFile(
      history: h.history,
      store: h.store,
      exporter: exporter,
      recorder: recorderFor(h.audit),
    )(id, ExportMode.saveToDevice);
    expect(h.audit.events.where((e) => e.eventType == 'data_export.shared'), isEmpty);
  });

  test('sharing a file that is gone is refused', () async {
    h.store.files.remove(fileName);
    final r = await ShareExportFile(
      history: h.history,
      store: h.store,
      exporter: _Exporter(),
      recorder: recorderFor(h.audit),
    )(id, ExportMode.share);
    expect(r.failureOrNull, isA<NotFoundFailure>());
  });

  test('deleting the file keeps the record and notes it in the audit trail', () async {
    final delete = DeleteExportFile(
      history: h.history,
      store: h.store,
      recorder: recorderFor(h.audit),
      clock: StepClock(DateTime.utc(2026, 8)),
    );
    expect((await delete(id)).isSuccess, isTrue);
    expect(h.store.files, isEmpty);
    expect(h.history.records.single.hasFile, isFalse);
    expect(h.audit.events.where((e) => e.eventType == 'data_export.file_deleted'), hasLength(1));
    // Doing it again changes nothing.
    expect((await delete(id)).isSuccess, isTrue);
    expect(h.audit.events.where((e) => e.eventType == 'data_export.file_deleted'), hasLength(1));
  });
}
