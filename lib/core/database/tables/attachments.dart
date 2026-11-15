import 'package:drift/drift.dart';

/// Files attached to business records (receipts of expenses for now).
///
/// The owner is referenced by `owner_type` + `owner_id` rather than a
/// foreign key so other record types can use the table later; triggers in
/// `schema_extras.dart` enforce that an expense exists and is still open
/// for attachments. Rows are never updated.
@DataClassName('AttachmentRow')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get ownerType =>
      text().customConstraint("NOT NULL CHECK (owner_type IN ('expense'))")();
  TextColumn get ownerId => text()();
  TextColumn get fileName => text()();

  /// Path relative to the application directory.
  TextColumn get storedPath => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get sizeBytes =>
      integer().customConstraint('NOT NULL CHECK (size_bytes >= 0)')();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
