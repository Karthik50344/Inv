import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/taxation/data/tax_snapshot_persistence.dart';
import 'package:inventrix/features/sales/data/mappers/sales_mapper.dart';
import 'package:inventrix/features/sales/domain/entities/sales_filter.dart';
import 'package:inventrix/features/sales/domain/entities/sales_invoice.dart';
import 'package:inventrix/features/sales/domain/entities/sales_summary.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Drift implementation of [SalesRepository].
///
/// Status changes are guarded `UPDATE ... WHERE status IN (...)` statements,
/// so a stale caller can never overwrite a newer state, and the database
/// triggers (see `schema_extras.dart`) keep posted invoices immutable.
final class DriftSalesRepository implements SalesRepository {
  /// Creates the repository.
  const DriftSalesRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  static const Set<DocumentStatus> _postable = {
    DocumentStatus.draft,
    DocumentStatus.created,
    DocumentStatus.approved,
    DocumentStatus.authorized,
  };

  @override
  Future<Result<List<SalesSummary>>> search(SalesFilter filter) =>
      guardDatabase(() async {
        final where = <String>[];
        final variables = <Variable<Object>>[];
        final status = filter.status;
        if (status != null) {
          where.add('i.status = ?');
          variables.add(Variable.withString(status.dbName));
        }
        final customerId = filter.customerId;
        if (customerId != null) {
          where.add('i.customer_id = ?');
          variables.add(Variable.withString(customerId));
        }
        final text = filter.query.trim().toLowerCase();
        if (text.isNotEmpty) {
          final pattern = '%${_escapeLike(text)}%';
          where.add(
            "(lower(COALESCE(i.number, '')) LIKE ? ESCAPE '\\' "
            "OR lower(i.customer_name) LIKE ? ESCAPE '\\' "
            "OR lower(COALESCE(i.customer_reference, '')) LIKE ? ESCAPE '\\')",
          );
          variables.addAll([
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ]);
        }
        final rows = await _db
            .customSelect(
              'SELECT i.id, i.number, i.customer_id, i.customer_name, '
              'i.status, i.invoice_date, i.due_date, i.customer_reference, '
              'i.currency_code, i.decimal_places, i.total_minor, '
              '(SELECT COUNT(*) FROM sales_invoice_items li '
              'WHERE li.invoice_id = i.id) AS line_count '
              'FROM sales_invoices i '
              '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
              'ORDER BY i.invoice_date DESC, i.created_at DESC, i.id DESC',
              variables: variables,
              readsFrom: {_db.salesInvoices, _db.salesInvoiceItems},
            )
            .get();
        return rows.map(summaryFromRow).toList();
      });

  @override
  Future<Result<SalesInvoice>> getById(String id) => guardDatabase(() async {
    final header = await (_db.select(
      _db.salesInvoices,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (header == null) {
      throw const FailureException(NotFoundFailure('Sales not found.'));
    }
    final items = await (_db.select(
      _db.salesInvoiceItems,
    )..where((t) => t.invoiceId.equals(id))).get();
    return invoiceFromRows(header, items);
  });

  @override
  Future<Result<void>> saveDraft(SalesInvoice invoice) => guardDatabase(
    () => _db.transaction(() async {
      final existing = await (_db.select(
        _db.salesInvoices,
      )..where((t) => t.id.equals(invoice.id))).getSingleOrNull();
      if (existing == null) {
        await _db.into(_db.salesInvoices).insert(invoiceToCompanion(invoice));
      } else {
        if (existing.status != DocumentStatus.draft.dbName) {
          throw const FailureException(
            ValidationFailure('Only draft sales can be edited.'),
          );
        }
        await (_db.update(_db.salesInvoices)
              ..where((t) => t.id.equals(invoice.id)))
            .write(invoiceToCompanion(invoice));
        await TaxSnapshotPersistence.clearForInvoice(
          _db,
          documentType: 'sales',
          invoiceId: invoice.id,
        );
        await (_db.delete(
          _db.salesInvoiceItems,
        )..where((t) => t.invoiceId.equals(invoice.id))).go();
      }
      for (final line in invoice.lines) {
        await _db
            .into(_db.salesInvoiceItems)
            .insert(lineToCompanion(line, invoice.id));
        await TaxSnapshotPersistence.insertForLine(
          _db,
          documentType: 'sales',
          itemId: line.id,
          snapshot: line.taxSnapshot,
        );
      }
    }),
  );

  @override
  Future<Result<void>> changeStatus(
    String id, {
    required Set<DocumentStatus> from,
    required DocumentStatus to,
    required DateTime at,
  }) => _guardedUpdate(
    id,
    from,
    SalesInvoicesCompanion(
      status: Value(to.dbName),
      updatedAt: Value(toEpochMs(at)),
      cancelledAt: to == DocumentStatus.cancelled
          ? Value(toEpochMs(at))
          : const Value.absent(),
    ),
  );

  @override
  Future<Result<void>> markPosted(
    String id, {
    required String number,
    required DateTime at,
  }) => _guardedUpdate(
    id,
    _postable,
    SalesInvoicesCompanion(
      status: Value(DocumentStatus.posted.dbName),
      number: Value(number),
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
    SalesInvoicesCompanion(
      status: Value(DocumentStatus.voided.dbName),
      voidedAt: Value(toEpochMs(at)),
      voidReason: Value(reason),
      updatedAt: Value(toEpochMs(at)),
    ),
  );

  @override
  Future<Result<Money>> postedTotalForCustomer(String customerId) =>
      guardDatabase(() async {
        final currencyResult = await _settings.getCurrencyConfig();
        final currency = currencyResult.valueOrNull;
        if (currency == null) {
          throw FailureException(currencyResult.failureOrNull!);
        }
        final row = await _db
            .customSelect(
              'SELECT COALESCE(SUM(total_minor), 0) AS total '
              'FROM sales_invoices '
              "WHERE customer_id = ? AND status = 'posted' "
              'AND currency_code = ? AND decimal_places = ?',
              variables: [
                Variable.withString(customerId),
                Variable.withString(currency.currencyCode),
                Variable.withInt(currency.decimalPlaces),
              ],
              readsFrom: {_db.salesInvoices},
            )
            .getSingle();
        return currency.fromMinor(row.read<int>('total'));
      });

  Future<Result<void>> _guardedUpdate(
    String id,
    Set<DocumentStatus> from,
    SalesInvoicesCompanion changes,
  ) => guardDatabase(() async {
    final affected =
        await (_db.update(_db.salesInvoices)..where(
              (t) =>
                  t.id.equals(id) &
                  t.status.isIn([for (final s in from) s.dbName]),
            ))
            .write(changes);
    if (affected == 0) {
      final exists = await (_db.select(
        _db.salesInvoices,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      throw FailureException(
        exists == null
            ? const NotFoundFailure('Sales not found.')
            : const ValidationFailure(
                'This sale was changed in the meantime. '
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
