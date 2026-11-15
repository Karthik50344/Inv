import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/expenses/data/mappers/expense_mapper.dart';
import 'package:inventrix/features/expenses/domain/entities/expense.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_attachment.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_filter.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_report.dart';
import 'package:inventrix/features/expenses/domain/entities/expense_summary.dart';
import 'package:inventrix/features/expenses/domain/repositories/expense_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Drift implementation of [ExpenseRepository].
///
/// Status changes are guarded `UPDATE ... WHERE status IN (...)` statements,
/// so a stale caller can never overwrite a newer state, and the database
/// triggers (see `schema_extras.dart`) keep posted expenses immutable.
final class DriftExpenseRepository implements ExpenseRepository {
  /// Creates the repository.
  const DriftExpenseRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  @override
  Future<Result<List<ExpenseSummary>>> search(ExpenseFilter filter) =>
      guardDatabase(() async {
        final where = <String>[];
        final variables = <Variable<Object>>[];
        final status = filter.status;
        if (status != null) {
          where.add('e.status = ?');
          variables.add(Variable.withString(status.dbName));
        }
        final categoryId = filter.categoryId;
        if (categoryId != null) {
          where.add('e.category_id = ?');
          variables.add(Variable.withString(categoryId));
        }
        final from = filter.from;
        if (from != null) {
          where.add('e.expense_date >= ?');
          variables.add(Variable.withInt(toEpochMs(from)));
        }
        final to = filter.to;
        if (to != null) {
          where.add('e.expense_date <= ?');
          variables.add(Variable.withInt(toEpochMs(to)));
        }
        final text = filter.query.trim().toLowerCase();
        if (text.isNotEmpty) {
          final pattern = '%${_escapeLike(text)}%';
          where.add(
            "(lower(COALESCE(e.number, '')) LIKE ? ESCAPE '\\' "
            "OR lower(e.description) LIKE ? ESCAPE '\\' "
            "OR lower(COALESCE(e.payee, '')) LIKE ? ESCAPE '\\' "
            "OR lower(e.category_name) LIKE ? ESCAPE '\\' "
            "OR lower(COALESCE(e.reference, '')) LIKE ? ESCAPE '\\')",
          );
          for (var i = 0; i < 5; i++) {
            variables.add(Variable.withString(pattern));
          }
        }
        final rows = await _db
            .customSelect(
              'SELECT e.id, e.number, e.status, e.expense_date, '
              'e.category_id, e.category_name, e.description, e.payee, '
              'e.method_name, e.currency_code, e.decimal_places, '
              'e.total_minor '
              'FROM expenses e '
              '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
              'ORDER BY e.expense_date DESC, e.created_at DESC, e.id DESC',
              variables: variables,
              readsFrom: {_db.expenses},
            )
            .get();
        return rows.map(summaryFromRow).toList();
      });

  @override
  Future<Result<Expense>> getById(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.expenses,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('Expense not found.'));
    }
    final attachments =
        await (_db.select(_db.attachments)..where(
              (t) => t.ownerType.equals('expense') & t.ownerId.equals(id),
            ))
            .get();
    return expenseFromRows(row, attachments);
  });

  @override
  Future<Result<void>> saveDraft(Expense expense) => guardDatabase(
    () => _db.transaction(() async {
      final existing = await (_db.select(
        _db.expenses,
      )..where((t) => t.id.equals(expense.id))).getSingleOrNull();
      if (existing == null) {
        await _db.into(_db.expenses).insert(expenseToCompanion(expense));
        return;
      }
      if (existing.status != DocumentStatus.draft.dbName) {
        throw const FailureException(
          ValidationFailure('Only draft expenses can be edited.'),
        );
      }
      await (_db.update(_db.expenses)..where((t) => t.id.equals(expense.id)))
          .write(expenseToCompanion(expense));
    }),
  );

  @override
  Future<Result<void>> markCancelled(String id, {required DateTime at}) =>
      _guardedUpdate(
        id,
        {DocumentStatus.draft},
        ExpensesCompanion(
          status: Value(DocumentStatus.cancelled.dbName),
          cancelledAt: Value(toEpochMs(at)),
          updatedAt: Value(toEpochMs(at)),
        ),
      );

  @override
  Future<Result<void>> markPosted(
    String id, {
    required String number,
    required String categoryName,
    required String methodName,
    required DateTime at,
  }) => _guardedUpdate(
    id,
    {DocumentStatus.draft},
    ExpensesCompanion(
      status: Value(DocumentStatus.posted.dbName),
      number: Value(number),
      categoryName: Value(categoryName),
      methodName: Value(methodName),
      postedAt: Value(toEpochMs(at)),
      updatedAt: Value(toEpochMs(at)),
    ),
  );

  @override
  Future<Result<void>> markVoided(
    String id, {
    required String reason,
    required DateTime at,
  }) => _guardedUpdate(
    id,
    {DocumentStatus.posted},
    ExpensesCompanion(
      status: Value(DocumentStatus.voided.dbName),
      voidedAt: Value(toEpochMs(at)),
      voidReason: Value(reason),
      updatedAt: Value(toEpochMs(at)),
    ),
  );

  @override
  Future<Result<void>> addAttachment(ExpenseAttachment attachment) =>
      guardDatabase(
        () =>
            _db.into(_db.attachments).insert(attachmentToCompanion(attachment)),
      );

  @override
  Future<Result<void>> removeAttachment(String attachmentId) =>
      guardDatabase(() async {
        final affected = await (_db.delete(
          _db.attachments,
        )..where((t) => t.id.equals(attachmentId))).go();
        if (affected == 0) {
          throw const FailureException(
            NotFoundFailure('This attachment no longer exists.'),
          );
        }
      });

  @override
  Future<Result<ExpenseReport>> report(ExpenseReportFilter filter) =>
      guardDatabase(() async {
        final currencyResult = await _settings.getCurrencyConfig();
        final currency = currencyResult.valueOrNull;
        if (currency == null) {
          throw FailureException(currencyResult.failureOrNull!);
        }
        final conditions = <String>[
          "status = 'posted'",
          'expense_date >= ?',
          'expense_date <= ?',
        ];
        final variables = <Variable<Object>>[
          Variable.withInt(toEpochMs(filter.from)),
          Variable.withInt(toEpochMs(filter.to)),
        ];
        final categoryId = filter.categoryId;
        if (categoryId != null) {
          conditions.add('category_id = ?');
          variables.add(Variable.withString(categoryId));
        }
        final where = conditions.join(' AND ');

        final rows = await _db
            .customSelect(
              'SELECT category_id, MIN(category_name) AS category_name, '
              'COUNT(*) AS cnt, SUM(net_minor) AS net, '
              'SUM(tax_minor) AS tax, SUM(total_minor) AS total '
              'FROM expenses '
              'WHERE $where AND currency_code = ? AND decimal_places = ? '
              'GROUP BY category_id '
              'ORDER BY total DESC, category_name ASC',
              variables: [
                ...variables,
                Variable.withString(currency.currencyCode),
                Variable.withInt(currency.decimalPlaces),
              ],
              readsFrom: {_db.expenses},
            )
            .get();
        final other = await _db
            .customSelect(
              'SELECT COUNT(*) AS cnt FROM expenses '
              'WHERE $where AND NOT (currency_code = ? AND decimal_places = ?)',
              variables: [
                ...variables,
                Variable.withString(currency.currencyCode),
                Variable.withInt(currency.decimalPlaces),
              ],
              readsFrom: {_db.expenses},
            )
            .getSingle();

        final totals = [
          for (final row in rows)
            ExpenseCategoryTotal(
              categoryId: row.read<String>('category_id'),
              categoryName: row.read<String>('category_name'),
              count: row.read<int>('cnt'),
              net: currency.fromMinor(row.read<int>('net')),
              tax: currency.fromMinor(row.read<int>('tax')),
              total: currency.fromMinor(row.read<int>('total')),
            ),
        ];
        var count = 0;
        var net = currency.zero();
        var tax = currency.zero();
        var total = currency.zero();
        for (final t in totals) {
          count += t.count;
          net += t.net;
          tax += t.tax;
          total += t.total;
        }
        return ExpenseReport(
          filter: filter,
          count: count,
          net: net,
          tax: tax,
          total: total,
          byCategory: totals,
          otherCurrencyCount: other.read<int>('cnt'),
        );
      });

  Future<Result<void>> _guardedUpdate(
    String id,
    Set<DocumentStatus> from,
    ExpensesCompanion changes,
  ) => guardDatabase(() async {
    final affected =
        await (_db.update(_db.expenses)..where(
              (t) =>
                  t.id.equals(id) &
                  t.status.isIn([for (final s in from) s.dbName]),
            ))
            .write(changes);
    if (affected == 0) {
      final exists = await (_db.select(
        _db.expenses,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      throw FailureException(
        exists == null
            ? const NotFoundFailure('Expense not found.')
            : const ValidationFailure(
                'This expense was changed in the meantime. '
                'Reload it and try again.',
              ),
      );
    }
  });

  static String _escapeLike(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
