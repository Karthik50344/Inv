import 'package:drift/drift.dart';

/// Audit events waiting to be written because the audit write failed after
/// the business action had already happened (work that cannot share a
/// database transaction). Entries are removed once written to the chain.
@DataClassName('AuditOutboxRow')
class AuditOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  IntColumn get createdAt => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
