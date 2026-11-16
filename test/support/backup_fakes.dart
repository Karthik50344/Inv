import 'dart:io';

import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/backup/data/services/app_storage_locations.dart';
import 'package:inventrix/features/backup/domain/entities/backup_record.dart';
import 'package:inventrix/features/backup/domain/entities/database_inspection.dart';
import 'package:inventrix/features/backup/domain/entities/restore_journal.dart';
import 'package:inventrix/features/backup/domain/repositories/app_runtime.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_history_repository.dart';
import 'package:inventrix/features/backup/domain/repositories/database_inspector.dart';
import 'package:inventrix/features/backup/domain/repositories/database_snapshotter.dart';
import 'package:inventrix/features/backup/domain/repositories/restore_journal_store.dart';

/// Clock that moves only when told to.
class FakeClock implements Clock {
  DateTime current = DateTime.utc(2026, 11, 15, 10);
  @override
  DateTime now() => current;
}

/// Sequential ids.
class SeqIds implements IdGenerator {
  int _n = 0;
  @override
  String newId() => 'id-${++_n}';
}

/// "Database" is a text file whose content identifies the data set.
class FakeSnapshotter implements DatabaseSnapshotter {
  FakeSnapshotter(this.liveDatabase);
  final File liveDatabase;
  Failure? failWith;
  @override
  Future<Result<void>> snapshotTo(String targetPath) async {
    if (failWith != null) {
      return Result.failure(failWith!);
    }
    await liveDatabase.copy(targetPath);
    return const Result.success(null);
  }
}

/// Inspector that treats file content `corrupt` as damaged and otherwise
/// reports [schemaVersion].
class FakeInspector implements DatabaseInspector {
  FakeInspector({this.schemaVersion = 9});
  int schemaVersion;
  Failure? migrateFailure;
  final List<String> migrated = [];
  @override
  int get appSchemaVersion => 9;

  Future<DatabaseInspection> _look(String path) async {
    final text = await File(path).readAsString();
    return DatabaseInspection(
      schemaVersion: schemaVersion,
      integrityMessages: text.contains('corrupt') ? ['bad page'] : ['ok'],
      foreignKeyViolations: 0,
      recordCounts: {'products': text.length},
    );
  }

  @override
  Future<Result<DatabaseInspection>> inspect(String path) async =>
      Result.success(await _look(path));

  @override
  Future<Result<DatabaseInspection>> migrateAndInspect(String path) async {
    if (migrateFailure != null) {
      return Result.failure(migrateFailure!);
    }
    migrated.add(path);
    return Result.success(await _look(path));
  }
}

class InMemoryHistory implements BackupHistoryRepository {
  final Map<String, BackupRecord> rows = {};
  bool failAdd = false;
  @override
  Future<Result<void>> add(BackupRecord record) async {
    if (failAdd) {
      return const Result.failure(DatabaseFailure('nope'));
    }
    rows.putIfAbsent(record.id, () => record);
    return const Result.success(null);
  }

  @override
  Future<Result<List<BackupRecord>>> list() async =>
      Result.success(rows.values.toList().reversed.toList());

  @override
  Future<Result<BackupRecord>> getById(String id) async => rows[id] == null
      ? const Result.failure(NotFoundFailure('missing'))
      : Result.success(rows[id]!);

  @override
  Future<Result<void>> markExported(String id, DateTime at) async {
    rows[id] = rows[id]!.copyWith(exportedAt: at);
    return const Result.success(null);
  }

  @override
  Future<Result<void>> clearStoredPath(String id) async {
    rows[id] = rows[id]!.copyWith(clearStoredPath: true);
    return const Result.success(null);
  }
}

class InMemoryJournal implements RestoreJournalStore {
  RestoreJournalEntry? entry;
  final List<RestoreJournalState> states = [];
  @override
  Future<void> clear() async => entry = null;
  @override
  Future<RestoreJournalEntry?> read() async => entry;
  @override
  Future<void> write(RestoreJournalEntry value) async {
    entry = value;
    states.add(value.state);
  }
}

/// Runtime that records calls and can fail on demand. [onShutDown] and
/// [onStart] let tests inspect or damage the files at that moment.
class FakeRuntime implements AppRuntime {
  final List<String> calls = [];
  Object? shutDownError;
  int startFailures = 0;
  Future<void> Function()? onShutDown;
  Future<void> Function()? onStart;
  @override
  Future<void> shutDown() async {
    calls.add('shutDown');
    if (shutDownError != null) {
      throw shutDownError!;
    }
    await onShutDown?.call();
  }

  @override
  Future<void> start() async {
    calls.add('start');
    await onStart?.call();
    if (startFailures > 0) {
      startFailures--;
      throw StateError('cannot open');
    }
  }
}

class FakeExporter implements BackupExporter {
  final List<String> exported = [];
  bool completes = true;
  @override
  Future<Result<ExportResult>> export({
    required String path,
    required String fileName,
    required ExportMode mode,
  }) async {
    exported.add('$fileName:${mode.name}');
    return Result.success(ExportResult(completed: completes));
  }
}

/// Real folder layout in a temp directory.
class TestStorage {
  TestStorage._(this.root, this.locations, this.database);
  final Directory root;
  final AppStorageLocations locations;
  final File database;
  Directory get docs => Directory('${root.path}/docs');

  static Future<TestStorage> create() async {
    final root = await Directory.systemTemp.createTemp('inventrix_test_');
    final docs = Directory('${root.path}/docs')..createSync();
    final temp = Directory('${root.path}/tmp')..createSync();
    final db = File('${docs.path}/inventory_management.sqlite')
      ..writeAsStringSync('live-data');
    final locations = AppStorageLocations(
      documents: () async => docs,
      temporary: () async => temp,
      databasePath: () async => db.path,
    );
    return TestStorage._(root, locations, db);
  }

  Future<void> dispose() => root.delete(recursive: true);
}
