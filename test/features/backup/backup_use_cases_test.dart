import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/backup/data/services/file_restore_swapper.dart';
import 'package:inventrix/features/backup/data/services/zip_backup_packager.dart';
import 'package:inventrix/features/backup/domain/entities/backup_kind.dart';
import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';
import 'package:inventrix/features/backup/domain/entities/staged_backup.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_packager.dart';
import 'package:inventrix/features/backup/domain/usecases/create_backup.dart';
import 'package:inventrix/features/backup/domain/usecases/manage_backups.dart';
import 'package:inventrix/features/backup/domain/usecases/prepare_restore.dart';
import 'package:inventrix/features/backup/domain/usecases/recover_restore.dart';
import 'package:inventrix/features/backup/domain/usecases/restore_backup.dart';

import '../../support/backup_fakes.dart';

void main() {
  late TestStorage storage;
  late FakeClock clock;
  late SeqIds ids;
  late FakeSnapshotter snapshotter;
  late FakeInspector inspector;
  late ZipBackupPackager packager;
  late InMemoryHistory history;
  late InMemoryJournal journal;
  late FakeRuntime runtime;
  late FileRestoreSwapper swapper;
  late CreateBackup create;
  late PrepareRestore prepare;
  late RestoreBackup restore;

  setUp(() async {
    storage = await TestStorage.create();
    clock = FakeClock();
    ids = SeqIds();
    snapshotter = FakeSnapshotter(storage.database);
    inspector = FakeInspector();
    packager = ZipBackupPackager();
    history = InMemoryHistory();
    journal = InMemoryJournal();
    runtime = FakeRuntime();
    swapper = FileRestoreSwapper();
    create = CreateBackup(
      snapshotter: snapshotter,
      inspector: inspector,
      packager: packager,
      locations: storage.locations,
      history: history,
      ids: ids,
      clock: clock,
      appVersion: '1.0.0',
    );
    prepare = PrepareRestore(
      packager: packager,
      inspector: inspector,
      locations: storage.locations,
    );
    restore = RestoreBackup(
      inspector: inspector,
      locations: storage.locations,
      createBackup: create,
      swapper: swapper,
      journal: journal,
      runtime: runtime,
      ids: ids,
      clock: clock,
    );
    Directory('${storage.docs.path}/attachments').createSync();
    File('${storage.docs.path}/attachments/live.pdf')
        .writeAsStringSync('live-receipt');
  });
  tearDown(() => storage.dispose());

  String db() => storage.database.readAsStringSync();

  /// Makes a backup of [content], then changes the live data to [after].
  Future<String> backupThenChange(String content, String after) async {
    storage.database.writeAsStringSync(content);
    final record = (await create()).valueOrNull!;
    storage.database.writeAsStringSync(after);
    return (await storage.locations.resolveBackup(record.storedPath!));
  }

  group('CreateBackup', () {
    test('creates a verified archive and records it', () async {
      final result = await create();
      final record = result.valueOrNull!;
      expect(record.kind, BackupKind.backup);
      expect(record.sha256!.length, 64);
      expect(record.fileName, 'inventrix_backup_20261115_100000.zip');
      expect(history.rows[record.id], record);
      expect(await storage.locations.backupExists(record.storedPath!), isTrue);
    });

    test('two backups in the same second never overwrite each other', () async {
      final a = (await create()).valueOrNull!;
      final b = (await create()).valueOrNull!;
      expect(a.fileName, isNot(b.fileName));
      expect(await storage.locations.backupExists(a.storedPath!), isTrue);
    });

    test('a damaged database is not backed up', () async {
      storage.database.writeAsStringSync('corrupt');
      final result = await create();
      expect(result.failureOrNull, isA<BackupFailure>());
      expect(history.rows.values.single.outcome, BackupOutcome.failed);
      expect(
        Directory(await storage.locations.backupsDirectory()).listSync(),
        isEmpty,
      );
    });

    test('snapshot failure is reported and leaves no files', () async {
      snapshotter.failWith = const DatabaseFailure('boom');
      expect((await create()).failureOrNull, isA<DatabaseFailure>());
      expect(
        Directory(await storage.locations.backupsDirectory()).listSync(),
        isEmpty,
      );
    });

    test('temp work folder is removed', () async {
      await create();
      final temp = Directory('${storage.root.path}/tmp');
      expect(temp.listSync(), isEmpty);
    });

    test('a restore cannot be created as a backup', () async {
      expect(
        (await create(kind: BackupKind.restore)).failureOrNull,
        isA<ValidationFailure>(),
      );
    });
  });

  group('ListBackups / DeleteStoredBackup / ExportBackup', () {
    test('list drops stored copies that vanished', () async {
      final record = (await create()).valueOrNull!;
      File(await storage.locations.resolveBackup(record.storedPath!))
          .deleteSync();
      final list = await ListBackups(
        history: history,
        locations: storage.locations,
      )();
      expect(list.valueOrNull!.single.hasStoredCopy, isFalse);
      expect(history.rows[record.id]!.storedPath, isNull);
    });

    test('delete removes the file but keeps the history row', () async {
      final record = (await create()).valueOrNull!;
      final deleted = await DeleteStoredBackup(
        history: history,
        locations: storage.locations,
      )(record.id);
      expect(deleted.isSuccess, isTrue);
      expect(await storage.locations.backupExists(record.fileName), isFalse);
      expect(history.rows.containsKey(record.id), isTrue);
    });

    test('export marks the record and refuses a modified file', () async {
      final exporter = FakeExporter();
      final export = ExportBackup(
        history: history,
        locations: storage.locations,
        packager: packager,
        exporter: exporter,
        clock: clock,
      );
      final record = (await create()).valueOrNull!;
      expect((await export(record.id, ExportMode.share)).valueOrNull, isTrue);
      expect(history.rows[record.id]!.exportedAt, isNotNull);

      final path = await storage.locations.resolveBackup(record.storedPath!);
      File(path).writeAsBytesSync([...File(path).readAsBytesSync(), 0]);
      final again = await export(record.id, ExportMode.saveToDevice);
      expect(again.failureOrNull, isA<BackupFailure>());
      expect(exporter.exported, hasLength(1));
    });

    test('cancelled export does not mark the record', () async {
      final exporter = FakeExporter()..completes = false;
      final record = (await create()).valueOrNull!;
      final result = await ExportBackup(
        history: history,
        locations: storage.locations,
        packager: packager,
        exporter: exporter,
        clock: clock,
      )(record.id, ExportMode.share);
      expect(result.valueOrNull, isFalse);
      expect(history.rows[record.id]!.exportedAt, isNull);
    });
  });

  group('PrepareRestore', () {
    test('returns a preview and leaves live data alone', () async {
      final archive = await backupThenChange('old-data', 'live-now');
      final preview = (await prepare(archive)).valueOrNull!;
      expect(preview.inspection.isHealthy, isTrue);
      expect(db(), 'live-now');
      expect(File(preview.staged.databasePath).readAsStringSync(), 'old-data');
    });

    test('refuses a newer schema and cleans staging', () async {
      final archive = await backupThenChange('old-data', 'live-now');
      inspector.schemaVersion = 12;
      final result = await prepare(archive);
      expect(result.failureOrNull, isA<RestoreFailure>());
      expect(
        Directory('${storage.docs.path}/restore_staging').listSync(),
        isEmpty,
      );
    });

    test('refuses a backup whose database is damaged', () async {
      storage.database.writeAsStringSync('corrupt');
      // Package a corrupt snapshot directly, bypassing CreateBackup's check.
      final out = '${storage.root.path}/c.zip';
      final packed = await packager.pack(
        PackRequest(
          databasePath: storage.database.path,
          dataFolders: const [],
          outputPath: out,
          createdAt: clock.now(),
          appVersion: '1.0.0',
          schemaVersion: 9,
        ),
      );
      expect(packed.isSuccess, isTrue);
      final result = await prepare(out);
      expect(result.failureOrNull!.message, contains('damaged'));
    });
  });

  group('RestoreBackup', () {
    Future<StagedBackup> staged(String content, String after) async =>
        (await prepare(await backupThenChange(content, after)))
            .valueOrNull!
            .staged;

    test(
      'requires explicit confirmation and changes nothing without it',
      () async {
        final s = await staged('old-data', 'live-now');
        final result = await restore(staged: s, confirmed: false);
        expect(result.failureOrNull, isA<ValidationFailure>());
        expect(runtime.calls, isEmpty);
        expect(db(), 'live-now');
      },
    );

    test('restores data and attachments, keeps a safety backup', () async {
      File('${storage.docs.path}/attachments/live.pdf')
          .writeAsStringSync('v-old');
      final s = await staged('old-data', 'live-now');
      File('${storage.docs.path}/attachments/live.pdf')
          .writeAsStringSync('v-new');
      File('${storage.docs.path}/attachments/extra.pdf').writeAsStringSync('x');

      final result = await restore(staged: s, confirmed: true);
      final outcome = result.valueOrNull!;
      expect(db(), 'old-data');
      expect(
        File('${storage.docs.path}/attachments/live.pdf').readAsStringSync(),
        'v-old',
      );
      expect(
        File('${storage.docs.path}/attachments/extra.pdf').existsSync(),
        isFalse,
      );
      expect(runtime.calls, ['shutDown', 'start']);
      expect(journal.entry!.state, RestoreJournalState.completed);
      expect(
        File('${storage.database.path}.pre_restore').existsSync(),
        isFalse,
      );
      expect(
        Directory('${storage.docs.path}/attachments.pre_restore').existsSync(),
        isFalse,
      );
      // The safety backup holds the data that was replaced.
      final safetyPath = await storage.locations.resolveBackup(
        outcome.safetyBackup.storedPath!,
      );
      final safetyStage = (await prepare(safetyPath)).valueOrNull!.staged;
      expect(File(safetyStage.databasePath).readAsStringSync(), 'live-now');
      expect(outcome.safetyBackup.kind, BackupKind.safety);
    });

    test('the swap happens while the database is closed', () async {
      final s = await staged('old-data', 'live-now');
      var closedDuringSwap = false;
      runtime.onShutDown = () async => closedDuringSwap = true;
      runtime.onStart = () async {
        expect(closedDuringSwap, isTrue);
        expect(storage.database.readAsStringSync(), 'old-data');
      };
      expect((await restore(staged: s, confirmed: true)).isSuccess, isTrue);
    });

    test(
      'a staged database that cannot be upgraded stops before anything happens',
      () async {
        final s = await staged('old-data', 'live-now');
        inspector.migrateFailure = const DatabaseFailure('migration failed');
        final result = await restore(staged: s, confirmed: true);
        expect(result.failureOrNull, isA<RestoreFailure>());
        expect(runtime.calls, isEmpty);
        expect(db(), 'live-now');
        expect(journal.entry, isNull);
      },
    );

    test('a failing safety backup stops the restore', () async {
      final s = await staged('old-data', 'live-now');
      snapshotter.failWith = const DatabaseFailure('disk full');
      final result = await restore(staged: s, confirmed: true);
      expect(result.failureOrNull!.message, contains('backed up first'));
      expect(runtime.calls, isEmpty);
      expect(db(), 'live-now');
    });

    test('shutDown failure changes nothing and restarts services', () async {
      final s = await staged('old-data', 'live-now');
      runtime.shutDownError = StateError('busy');
      final result = await restore(staged: s, confirmed: true);
      expect(result.isFailure, isTrue);
      expect(db(), 'live-now');
      expect(runtime.calls, ['shutDown', 'start']);
      expect(journal.entry, isNull);
    });

    test(
      'if the restored data cannot be opened, the old data comes back',
      () async {
        final s = await staged('old-data', 'live-now');
        File('${storage.docs.path}/attachments/live.pdf')
            .writeAsStringSync('keep-me');
        runtime.startFailures = 1;
        final result = await restore(staged: s, confirmed: true);
        expect(result.failureOrNull, isA<RestoreFailure>());
        expect(db(), 'live-now');
        expect(
          File('${storage.docs.path}/attachments/live.pdf').readAsStringSync(),
          'keep-me',
        );
        expect(runtime.calls, ['shutDown', 'start', 'start']);
        expect(journal.entry!.state, RestoreJournalState.rolledBack);
        expect(
          File('${storage.database.path}.pre_restore').existsSync(),
          isFalse,
        );
      },
    );

    test('a failed swap puts everything back', () async {
      final s = await staged('old-data', 'live-now');
      // A stale leftover from an earlier restore makes the swap refuse.
      File('${storage.database.path}.pre_restore').writeAsStringSync('stale');
      final result = await restore(staged: s, confirmed: true);
      expect(result.isFailure, isTrue);
      expect(db(), 'live-now');
      expect(
        File('${storage.database.path}.pre_restore').readAsStringSync(),
        'stale',
      );
      expect(runtime.calls, ['shutDown', 'start']);
    });
  });

  group('crash recovery', () {
    test('an interrupted swap is rolled back at next start', () async {
      final s = (await prepare(await backupThenChange('old-data', 'live-now')))
          .valueOrNull!
          .staged;
      final targets = RestoreTargets(
        databasePath: storage.database.path,
        dataFolders: await storage.locations.dataFolders(),
      );
      final safety = (await create(kind: BackupKind.safety)).valueOrNull!;
      await journal.write(
        RestoreJournalEntry(
          id: 'r1',
          state: RestoreJournalState.swapping,
          startedAt: clock.now(),
          sourceName: 'x.zip',
          restoredSchemaVersion: 9,
          targets: targets,
          safetyBackup: safety,
        ),
      );
      // Simulate dying right after the files were swapped.
      expect(
        (await swapper.swapIn(staged: s, targets: targets)).isSuccess,
        isTrue,
      );
      expect(db(), 'old-data');

      final recovered = await RecoverInterruptedRestore(
        journal: journal,
        swapper: swapper,
      )();
      expect(recovered, isTrue);
      expect(db(), 'live-now');
      expect(journal.entry!.state, RestoreJournalState.rolledBack);

      final notice = await ReconcileRestoreJournal(
        journal: journal,
        history: history,
        swapper: swapper,
        appVersion: '1.0.0',
      )();
      expect(notice!.succeeded, isFalse);
      expect(journal.entry, isNull);
      expect(
        history.rows.values
            .where((r) => r.kind == BackupKind.restore)
            .single
            .outcome,
        BackupOutcome.failed,
      );
    });

    test(
      'a completed restore is never rolled back and is reconciled once',
      () async {
        final s = (await prepare(
          await backupThenChange('old-data', 'live-now'),
        )).valueOrNull!.staged;
        expect((await restore(staged: s, confirmed: true)).isSuccess, isTrue);
        expect(
          await RecoverInterruptedRestore(journal: journal, swapper: swapper)(),
          isFalse,
        );
        expect(db(), 'old-data');

        final reconcile = ReconcileRestoreJournal(
          journal: journal,
          history: history,
          swapper: swapper,
          appVersion: '1.0.0',
        );
        final notice = await reconcile();
        expect(notice!.succeeded, isTrue);
        expect(notice.message, contains('inventrix_safety_'));
        expect(await reconcile(), isNull);
        expect(
          history.rows.values.where((r) => r.kind == BackupKind.safety),
          hasLength(1),
        );
      },
    );

    test('rollBack is a no-op when nothing was moved aside', () async {
      final targets = RestoreTargets(
        databasePath: storage.database.path,
        dataFolders: await storage.locations.dataFolders(),
      );
      expect((await swapper.rollBack(targets)).isSuccess, isTrue);
      expect(db(), 'live-data');
    });
  });
}
