import 'package:drift/drift.dart';

/// Per-document-kind counters for gap-free numbering (e.g. purchase
/// invoices). Incremented inside the same transaction that uses the number.
@DataClassName('DocumentSequenceRow')
class DocumentSequences extends Table {
  TextColumn get key => text()();
  IntColumn get lastValue =>
      integer().customConstraint('NOT NULL CHECK (last_value >= 0)')();

  @override
  Set<Column> get primaryKey => {key};
}
