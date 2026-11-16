import 'package:drift/drift.dart';

/// History of backups, safety copies and restores. The archives themselves
/// live in the app's `backups` folder; this table only describes them.
@DataClassName('BackupHistoryRow')
class BackupHistory extends Table {
  @override
  String get tableName => 'backup_history';

  TextColumn get id => text()();
  TextColumn get kind => text().customConstraint(
    "NOT NULL CHECK (kind IN ('backup','safety','restore'))",
  )();
  TextColumn get fileName => text()();

  /// Archive file name inside the backups folder; null once deleted.
  TextColumn get storedPath => text().nullable()();
  IntColumn get sizeBytes =>
      integer().customConstraint('NOT NULL CHECK (size_bytes >= 0)')();
  TextColumn get sha256 => text().nullable()();
  IntColumn get schemaVersion => integer()();
  TextColumn get appVersion => text()();
  TextColumn get outcome => text().customConstraint(
    "NOT NULL CHECK (outcome IN ('success','failed'))",
  )();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get exportedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
