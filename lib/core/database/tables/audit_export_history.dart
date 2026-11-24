import 'package:drift/drift.dart';

/// History of auditor exports. The file lives in the app's exports folder;
/// a record stays after its file is removed.
@DataClassName('AuditExportHistoryRow')
@TableIndex(name: 'idx_audit_export_history_created', columns: {#createdAt})
class AuditExportHistory extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();
  TextColumn get periodKind => text()();
  TextColumn get periodLabel => text()();
  TextColumn get periodFrom => text().nullable()();
  TextColumn get periodTo => text().nullable()();
  TextColumn get format => text()();
  TextColumn get datasets => text()();
  TextColumn get fileName => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get sha256 => text()();
  TextColumn get integrityStatus => text()();
  TextColumn get chainStatus => text()();
  TextColumn get appVersion => text()();
  IntColumn get schemaVersion => integer()();
  IntColumn get verifiedAt => integer().nullable()();
  IntColumn get fileDeletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    "CHECK (integrity_status IN ('verified', 'failed', 'not_checked'))",
    'CHECK (size_bytes >= 0)',
  ];
}
