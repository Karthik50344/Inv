import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_amounts.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_attachment.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_category.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_summary.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// The currency an expense was recorded in (its own snapshot, not the
/// current setting).
CurrencyConfig expenseCurrency(ExpenseRow row) => CurrencyConfig(
  currencyCode: row.currencyCode,
  decimalPlaces: row.decimalPlaces,
);

/// Expense row + attachment rows -> entity.
Expense expenseFromRows(ExpenseRow row, List<AttachmentRow> attachmentRows) {
  final currency = expenseCurrency(row);
  final sorted = [...attachmentRows]
    ..sort((a, b) {
      final byTime = a.createdAt.compareTo(b.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
  return Expense(
    id: row.id,
    number: row.number,
    status: DocumentStatus.fromDbName(row.status),
    expenseDate: fromEpochMs(row.expenseDate),
    categoryId: row.categoryId,
    categoryName: row.categoryName,
    description: row.description,
    payee: row.payee,
    methodId: row.methodId,
    methodName: row.methodName,
    reference: row.reference,
    notes: row.notes,
    amountIncludesTax: row.amountIncludesTax,
    taxRateId: row.taxRateId,
    taxName: row.taxName,
    taxRateBp: row.taxRateBp,
    amounts: ExpenseAmounts(
      net: currency.fromMinor(row.netMinor),
      tax: currency.fromMinor(row.taxMinor),
      total: currency.fromMinor(row.totalMinor),
    ),
    attachments: [for (final a in sorted) attachmentFromRow(a)],
    createdAt: fromEpochMs(row.createdAt),
    updatedAt: fromEpochMs(row.updatedAt),
    postedAt: fromEpochMsOrNull(row.postedAt),
    cancelledAt: fromEpochMsOrNull(row.cancelledAt),
    voidedAt: fromEpochMsOrNull(row.voidedAt),
    voidReason: row.voidReason,
  );
}

/// Entity -> insertable/updatable row (attachments are stored separately).
ExpensesCompanion expenseToCompanion(Expense expense) => ExpensesCompanion(
  id: Value(expense.id),
  number: Value(expense.number),
  status: Value(expense.status.dbName),
  expenseDate: Value(toEpochMs(expense.expenseDate)),
  categoryId: Value(expense.categoryId),
  categoryName: Value(expense.categoryName),
  description: Value(expense.description),
  payee: Value(expense.payee),
  methodId: Value(expense.methodId),
  methodName: Value(expense.methodName),
  reference: Value(expense.reference),
  notes: Value(expense.notes),
  currencyCode: Value(expense.amounts.total.currencyCode),
  decimalPlaces: Value(expense.amounts.total.decimalPlaces),
  amountIncludesTax: Value(expense.amountIncludesTax),
  taxRateId: Value(expense.taxRateId),
  taxName: Value(expense.taxName),
  taxRateBp: Value(expense.taxRateBp),
  netMinor: Value(expense.amounts.net.minorUnits),
  taxMinor: Value(expense.amounts.tax.minorUnits),
  totalMinor: Value(expense.amounts.total.minorUnits),
  postedAt: Value(toEpochMsOrNull(expense.postedAt)),
  cancelledAt: Value(toEpochMsOrNull(expense.cancelledAt)),
  voidedAt: Value(toEpochMsOrNull(expense.voidedAt)),
  voidReason: Value(expense.voidReason),
  createdAt: Value(toEpochMs(expense.createdAt)),
  updatedAt: Value(toEpochMs(expense.updatedAt)),
);

/// Attachment row -> entity.
ExpenseAttachment attachmentFromRow(AttachmentRow row) => ExpenseAttachment(
  id: row.id,
  expenseId: row.ownerId,
  fileName: row.fileName,
  storedPath: row.storedPath,
  mimeType: row.mimeType,
  sizeBytes: row.sizeBytes,
  createdAt: fromEpochMs(row.createdAt),
);

/// Entity -> attachment insert.
AttachmentsCompanion attachmentToCompanion(ExpenseAttachment attachment) =>
    AttachmentsCompanion(
      id: Value(attachment.id),
      ownerType: const Value('expense'),
      ownerId: Value(attachment.expenseId),
      fileName: Value(attachment.fileName),
      storedPath: Value(attachment.storedPath),
      mimeType: Value(attachment.mimeType),
      sizeBytes: Value(attachment.sizeBytes),
      createdAt: Value(toEpochMs(attachment.createdAt)),
    );

/// A joined list row (`SELECT e.* ...` as produced by the repository).
ExpenseSummary summaryFromRow(QueryRow row) {
  final currency = CurrencyConfig(
    currencyCode: row.read<String>('currency_code'),
    decimalPlaces: row.read<int>('decimal_places'),
  );
  return ExpenseSummary(
    id: row.read<String>('id'),
    number: row.readNullable<String>('number'),
    status: DocumentStatus.fromDbName(row.read<String>('status')),
    expenseDate: fromEpochMs(row.read<int>('expense_date')),
    categoryId: row.read<String>('category_id'),
    categoryName: row.read<String>('category_name'),
    description: row.read<String>('description'),
    payee: row.readNullable<String>('payee'),
    methodName: row.read<String>('method_name'),
    total: currency.fromMinor(row.read<int>('total_minor')),
  );
}

/// Category row -> entity.
ExpenseCategory categoryFromRow(ExpenseCategoryRow row) => ExpenseCategory(
  id: row.id,
  name: row.name,
  description: row.description,
  createdAt: fromEpochMs(row.createdAt),
  updatedAt: fromEpochMs(row.updatedAt),
  archivedAt: fromEpochMsOrNull(row.archivedAt),
);

/// Entity -> category row.
ExpenseCategoriesCompanion categoryToCompanion(ExpenseCategory category) =>
    ExpenseCategoriesCompanion(
      id: Value(category.id),
      name: Value(category.name),
      description: Value(category.description),
      createdAt: Value(toEpochMs(category.createdAt)),
      updatedAt: Value(toEpochMs(category.updatedAt)),
      archivedAt: Value(toEpochMsOrNull(category.archivedAt)),
    );
