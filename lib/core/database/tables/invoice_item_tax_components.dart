import 'package:drift/drift.dart';

/// Per-component tax of a document line, frozen with the document.
///
/// `item_id` points at a sales or purchase item (`document_type` says
/// which), so there is no foreign key; triggers keep rows writable only
/// while the parent invoice is a draft, exactly like the items themselves.
@DataClassName('InvoiceItemTaxComponentRow')
@TableIndex(name: 'idx_invoice_item_tax_components_item', columns: {#documentType, #itemId})
class InvoiceItemTaxComponents extends Table {
  TextColumn get id => text()();
  TextColumn get documentType => text()();
  TextColumn get itemId => text()();
  IntColumn get componentNo => integer()();
  TextColumn get ruleId => text()();
  TextColumn get componentId => text()();
  TextColumn get name => text()();
  TextColumn get componentType => text()();
  TextColumn get calculationMethod => text()();
  IntColumn get rateBasisPoints => integer().nullable()();
  IntColumn get fixedAmountMinor => integer().nullable()();
  IntColumn get taxableMinor => integer()();
  IntColumn get amountMinor => integer()();
  BoolColumn get isCompound => boolean()();
  BoolColumn get isRecoverable => boolean()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {documentType, itemId, componentNo},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (document_type IN ('sales', 'purchase'))",
    'CHECK (amount_minor >= 0 AND taxable_minor >= 0)',
  ];
}
