import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/backup/data/services/file_restore_swapper.dart';
import 'package:inventrix/features/backup/data/services/backup_envelope.dart';
import 'package:inventrix/features/backup/data/services/encrypted_backup_packager.dart';
import 'package:inventrix/features/backup/data/services/zip_backup_packager.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/features/backup/domain/usecases/create_backup.dart';
import 'package:inventrix/features/backup/domain/usecases/manage_backups.dart';
import 'package:inventrix/features/backup/domain/usecases/prepare_restore.dart';
import 'package:inventrix/features/backup/domain/usecases/restore_backup.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_event.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/backup_fakes.dart';

/// Real use cases and file system, fake database. (Written without a Flutter
/// SDK: the `bloc` package was not available, so not yet executed.)
void main() {
  late TestStorage storage;
  late InMemoryHistory history;
  late FakeRuntime runtime;
  late BackupBloc bloc;

  setUp(() async {
    storage = await TestStorage.create();
    history = InMemoryHistory();
    runtime = FakeRuntime();
    final clock = FakeClock();
    final ids = SeqIds();
    final snapshotter = FakeSnapshotter(storage.database);
    final inspector = FakeInspector();
    final keys = FakeKeys();
    final packager = EncryptedBackupPackager(
      inner: ZipBackupPackager(),
      keys: keys,
      locations: storage.locations,
      envelope: BackupEnvelope(argonMemoryKib: 64, argonIterations: 1),
    );
    final create = CreateBackup(
      snapshotter: snapshotter,
      inspector: inspector,
      packager: packager,
      locations: storage.locations,
      history: history,
      keys: keys,
      ids: ids,
      clock: clock,
      appVersion: '1.0.0',
    );
    bloc = BackupBloc(
      listBackups: ListBackups(history: history, locations: storage.locations),
      createBackup: create,
      exportBackup: ExportBackup(
        history: history,
        locations: storage.locations,
        packager: packager,
        exporter: FakeExporter(),
        clock: clock,
      ),
      deleteBackup: DeleteStoredBackup(
        history: history,
        locations: storage.locations,
      ),
      prepareRestore: PrepareRestore(
        packager: packager,
        inspector: inspector,
        locations: storage.locations,
      ),
      discardStaged: DiscardStagedBackup(locations: storage.locations),
      restoreBackup: RestoreBackup(
        inspector: inspector,
        locations: storage.locations,
        createBackup: create,
        keys: keys,
        aligner: FakeAligner(),
        swapper: FileRestoreSwapper(),
        journal: InMemoryJournal(),
        runtime: runtime,
        ids: ids,
        clock: clock,
      ),
      locations: storage.locations,
    );
  });
  tearDown(() async {
    await bloc.close();
    await storage.dispose();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 150));

  test('starts empty, then lists a created backup', () async {
    bloc.add(const BackupStarted());
    await settle();
    expect(bloc.state.status, ViewStatus.empty);

    bloc.add(const BackupCreateRequested());
    await settle();
    expect(bloc.state.status, ViewStatus.loaded);
    expect(bloc.state.records.single.kind, BackupKind.backup);
    expect(bloc.state.activity, BackupActivity.idle);
    expect(bloc.state.message, contains('Backup created'));
    expect(bloc.state.lastBackupAt, isNotNull);
  });

  test('export success reports and marks the record', () async {
    bloc.add(const BackupCreateRequested());
    await settle();
    final id = bloc.state.records.single.id;
    bloc.add(BackupExportRequested(id, ExportMode.share));
    await settle();
    expect(bloc.state.message, 'Backup exported.');
    expect(bloc.state.records.single.exportedAt, isNotNull);
  });

  test(
    'choosing a stored backup yields a preview; discarding clears it',
    () async {
      bloc.add(const BackupCreateRequested());
      await settle();
      bloc.add(BackupStoredSelected(bloc.state.records.single.id));
      await settle();
      expect(bloc.state.preview, isNotNull);
      bloc.add(const BackupPreviewDiscarded());
      await settle();
      expect(bloc.state.preview, isNull);
      expect(runtime.calls, isEmpty);
    },
  );

  test('a bad file shows an error and no preview', () async {
    bloc.add(const BackupFileSelected('/no/such/file.zip'));
    await settle();
    expect(bloc.state.preview, isNull);
    expect(bloc.state.error, isNotNull);
    expect(bloc.state.busy, isFalse);
  });

  test('confirming restores through the runtime', () async {
    bloc.add(const BackupCreateRequested());
    await settle();
    bloc.add(BackupStoredSelected(bloc.state.records.single.id));
    await settle();
    bloc.add(const BackupRestoreConfirmed());
    await settle();
    expect(runtime.calls, ['shutDown', 'start']);
    expect(bloc.state.preview, isNull);
  });

  test('delete removes the stored copy', () async {
    bloc.add(const BackupCreateRequested());
    await settle();
    bloc.add(BackupDeleteRequested(bloc.state.records.single.id));
    await settle();
    expect(bloc.state.records.single.hasStoredCopy, isFalse);
  });
}
