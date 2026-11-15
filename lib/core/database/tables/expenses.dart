import 'package:drift/drift.dart';
import 'package:inventrix/core/database/tables/expense_categories.dart';
import 'package:inventrix/core/database/tables/payment_methods.dart';
import 'package:inventrix/core/database/tables/tax_rates.dart';

/// Expenses. Posted expenses are immutable (see the triggers in
/// `schema_extras.dart`); they can only move to `voided`.
///
/// Category, payment method and tax names, the currency and every amount
/// are snapshots, so history stays correct when master data or settings
/// change.
@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();

  /// Assigned when posted (unique, enforced by a partial index).
  TextColumn get number => text().nullable()();
  TextColumn get status => text().customConstraint(
    'NOT NULL CHECK (status IN '
    "('draft','posted','cancelled','voided'))",
  )();
  IntColumn get expenseDate => integer()();
  TextColumn get categoryId =>
      text().references(ExpenseCategories, #id, onDelete: KeyAction.restrict)();
  TextColumn get categoryName => text()();
  TextColumn get description => text()();
  TextColumn get payee => text().nullable()();
  TextColumn get methodId =>
      text().references(PaymentMethods, #id, onDelete: KeyAction.restrict)();
  TextColumn get methodName => text()();
  TextColumn get reference => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get currencyCode => text()();
  IntColumn get decimalPlaces => integer().customConstraint(
    'NOT NULL CHECK (decimal_places BETWEEN 0 AND 4)',
  )();
  BoolColumn get amountIncludesTax => boolean()();
  TextColumn get taxRateId => text().nullable().references(
    TaxRates,
    #id,
    onDelete: KeyAction.restrict,
  )();
  TextColumn get taxName => text().nullable()();
  IntColumn get taxRateBp =>
      integer().customConstraint('NOT NULL CHECK (tax_rate_bp >= 0)')();
  IntColumn get netMinor =>
      integer().customConstraint('NOT NULL CHECK (net_minor >= 0)')();
  IntColumn get taxMinor =>
      integer().customConstraint('NOT NULL CHECK (tax_minor >= 0)')();
  IntColumn get totalMinor =>
      integer().customConstraint('NOT NULL CHECK (total_minor > 0)')();
  IntColumn get postedAt => integer().nullable()();
  IntColumn get cancelledAt => integer().nullable()();
  IntColumn get voidedAt => integer().nullable()();
  TextColumn get voidReason => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // A number exists exactly for documents that were posted.
    "CHECK ((number IS NOT NULL) = (status IN ('posted','voided')))",
    "CHECK (status NOT IN ('posted','voided') OR posted_at IS NOT NULL)",
    "CHECK (status <> 'voided' OR "
        '(voided_at IS NOT NULL AND void_reason IS NOT NULL))',
    'CHECK (total_minor = net_minor + tax_minor)',
  ];
}
