import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/purchases/data/mappers/purchase_mapper.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_filter.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_invoice.dart';
import 'package:inventrix/features/purchases/domain/entities/purchase_summary.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// Drift implementation of [PurchaseRepository].
///
/// Status changes are guarded `UPDATE ... WHERE status IN (...)` statements,
/// so a stale caller can never overwrite a newer state, and the database
/// triggers (see `schema_extras.dart`) keep posted invoices immutable.
final class DriftPurchaseRepository implements PurchaseRepository {
  /// Creates the repository.
  const DriftPurchaseRepository(this._db, this._settings);

  final AppDatabase _db;
  final SettingsRepository _settings;

  static const Set<DocumentStatus> _postable = {
    DocumentStatus.draft,
    DocumentStatus.created,
    DocumentStatus.approved,
    DocumentStatus.authorized,
  };

  @override
  Future<Result<List<PurchaseSummary>>> search(PurchaseFilter filter) =>
      guardDatabase(() async {
        final where = <String>[];
        final variables = <Variable<Object>>[];
        final status = filter.status;
        if (status != null) {
          where.add('i.status = ?');
          variables.add(Variable.withString(status.dbName));
        }
        final supplierId = filter.supplierId;
        if (supplierId != null) {
          where.add('i.supplier_id = ?');
          variables.add(Variable.withString(supplierId));
        }
        final text = filter.query.trim().toLowerCase();
        if (text.isNotEmpty) {
          final pattern = '%${_escapeLike(text)}%';
          where.add(
            "(lower(COALESCE(i.number, '')) LIKE ? ESCAPE '\\' "
            "OR lower(i.supplier_name) LIKE ? ESCAPE '\\' "
            "OR lower(COALESCE(i.supplier_reference, '')) LIKE ? ESCAPE '\\')",
          );
          variables.addAll([
            Variable.withString(pattern),
            Variable.withString(pattern),
            Variable.withString(pattern),
          ]);
        }
        final rows = await _db
            .customSelect(
              'SELECT i.id, i.number, i.supplier_id, i.supplier_name, '
              'i.status, i.invoice_date, i.due_date, i.supplier_reference, '
              'i.currency_code, i.decimal_places, i.total_minor, '
              '(SELECT COUNT(*) FROM purchase_invoice_items li '
              'WHERE li.invoice_id = i.id) AS line_count '
              'FROM purchase_invoices i '
              '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
              'ORDER BY i.invoice_date DESC, i.created_at DESC, i.id DESC',
              variables: variables,
              readsFrom: {_db.purchaseInvoices, _db.purchaseInvoiceItems},
            )
            .get();
        return rows.map(summaryFromRow).toList();
      });

  @override
  Future<Result<PurchaseInvoice>> getById(String id) => guardDatabase(() async {
    final header = await (_db.select(
      _db.purchaseInvoices,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (header == null) {
      throw const FailureException(NotFoundFailure('Purchase not found.'));
    }
    final items = await (_db.select(
      _db.purchaseInvoiceItems,
    )..where((t) => t.invoiceId.equals(id))).get();
    return invoiceFromRows(header, items);
  });

  @override
  Future<Result<void>> saveDraft(PurchaseInvoice invoice) => guardDatabase(
    () => _db.transaction(() async {
      final existing = await (_db.select(
        _db.purchaseInvoices,
      )..where((t) => t.id.equals(invoice.id))).getSingleOrNull();
      if (existing == null) {
        await _db
            .into(_db.purchaseInvoices)
            .insert(invoiceToCompanion(invoice));
      } else {
        if (existing.status != DocumentStatus.draft.dbName) {
          throw const FailureException(
            ValidationFailure('Only draft purchases can be edited.'),
          );
        }
        await (_db.update(_db.purchaseInvoices)
              ..where((t) => t.id.equals(invoice.id)))
            .write(invoiceToCompanion(invoice));
        await (_db.delete(
          _db.purchaseInvoiceItems,
        )..where((t) => t.invoiceId.equals(invoice.id))).go();
      }
      for (final line in invoice.lines) {
        await _db
            .into(_db.purchaseInvoiceItems)
            .insert(lineToCompanion(line, invoice.id));
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
    PurchaseInvoicesCompanion(
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
    PurchaseInvoicesCompanion(
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
    PurchaseInvoicesCompanion(
      status: Value(DocumentStatus.voided.dbName),
      voidedAt: Value(toEpochMs(at)),
      voidReason: Value(reason),
      updatedAt: Value(toEpochMs(at)),
    ),
  );

  @override
  Future<Result<Money>> postedTotalForSupplier(String supplierId) =>
      guardDatabase(() async {
        final currencyResult = await _settings.getCurrencyConfig();
        final currency = currencyResult.valueOrNull;
        if (currency == null) {
          throw FailureException(currencyResult.failureOrNull!);
        }
        final row = await _db
            .customSelect(
              'SELECT COALESCE(SUM(total_minor), 0) AS total '
              'FROM purchase_invoices '
              "WHERE supplier_id = ? AND status = 'posted' "
              'AND currency_code = ? AND decimal_places = ?',
              variables: [
                Variable.withString(supplierId),
                Variable.withString(currency.currencyCode),
                Variable.withInt(currency.decimalPlaces),
              ],
              readsFrom: {_db.purchaseInvoices},
            )
            .getSingle();
        return currency.fromMinor(row.read<int>('total'));
      });

  Future<Result<void>> _guardedUpdate(
    String id,
    Set<DocumentStatus> from,
    PurchaseInvoicesCompanion changes,
  ) => guardDatabase(() async {
    final affected =
        await (_db.update(_db.purchaseInvoices)..where(
              (t) =>
                  t.id.equals(id) &
                  t.status.isIn([for (final s in from) s.dbName]),
            ))
            .write(changes);
    if (affected == 0) {
      final exists = await (_db.select(
        _db.purchaseInvoices,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      throw FailureException(
        exists == null
            ? const NotFoundFailure('Purchase not found.')
            : const ValidationFailure(
                'This purchase was changed in the meantime. '
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
