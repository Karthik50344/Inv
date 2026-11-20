import 'package:drift/drift.dart';

/// A class of goods or services that share a tax treatment.
@DataClassName('TaxCategoryRow')
class TaxCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get code => text()();
  TextColumn get description => text().nullable()();
  TextColumn get defaultTaxTreatment => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {code},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (default_tax_treatment IN ('standard_rated', 'reduced_rated', "
        "'zero_rated', 'exempt', 'out_of_scope', 'reverse_charge'))",
  ];
}
