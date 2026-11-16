import 'dart:io';

import 'package:drift/native.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/backup/domain/entities/database_inspection.dart';
import 'package:inventrix/features/backup/domain/repositories/database_inspector.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';

/// [DatabaseInspector] that opens files with `sqlite3` directly.
final class SqliteDatabaseInspector implements DatabaseInspector {
  /// Creates the inspector.
  SqliteDatabaseInspector();

  static const List<String> _countedTables = [
    'products',
    'customers',
    'suppliers',
    'purchase_invoices',
    'sales_invoices',
    'payments',
    'expenses',
  ];

  final Logger _log = Logger('SqliteDatabaseInspector');

  @override
  int get appSchemaVersion => AppDatabase.currentSchemaVersion;

  @override
  Future<Result<DatabaseInspection>> inspect(String path) async {
    Database? db;
    try {
      db = sqlite3.open(path, mode: OpenMode.readOnly);
      final integrity = db
          .select('PRAGMA integrity_check')
          .map((row) => row.values.first.toString())
          .toList();
      final violations = db.select('PRAGMA foreign_key_check').length;
      final version = db.select('PRAGMA user_version').first.values.first;
      final existing = db
          .select("SELECT name FROM sqlite_master WHERE type = 'table'")
          .map((row) => row['name'] as String)
          .toSet();
      final counts = <String, int>{};
      for (final table in _countedTables) {
        if (existing.contains(table)) {
          counts[table] =
              db.select('SELECT count(*) AS c FROM $table').first['c'] as int;
        }
      }
      return Result.success(
        DatabaseInspection(
          schemaVersion: version as int,
          integrityMessages: integrity,
          foreignKeyViolations: violations,
          recordCounts: counts,
        ),
      );
    } on Object catch (error, stackTrace) {
      _log.warning('Inspection failed', error, stackTrace);
      return Result.failure(
        RestoreFailure(
          'The database inside this file could not be read.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      db?.dispose();
    }
  }

  @override
  Future<Result<DatabaseInspection>> migrateAndInspect(String path) async {
    final db = AppDatabase(NativeDatabase(File(path)));
    try {
      // Runs the same migrations and post-migration foreign-key check the
      // app runs at start-up.
      await db.initialize();
    } on Object catch (error, stackTrace) {
      _log.warning('Migration of staged copy failed', error, stackTrace);
      return Result.failure(
        RestoreFailure(
          'The data could not be upgraded to this version of the app.',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      await db.close();
    }
    return inspect(path);
  }
}
