import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/returns/domain/entities/return_document.dart';
import 'package:inventrix/features/returns/domain/entities/return_filter.dart';
import 'package:inventrix/features/returns/domain/entities/return_line.dart';
import 'package:inventrix/features/returns/domain/entities/return_summary.dart';
import 'package:inventrix/features/returns/domain/repositories/return_repository.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/services/invoice_return_lookup.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// Drift implementation of the returns contracts.
///
/// Sales and purchase returns live in two table pairs with the same shape;
/// one private description per kind ([_Tables]) keeps the SQL in one place.
/// Statements are plain SQL, so the repository does not depend on the
/// generated row classes. Rows are append-only (triggers in
/// `schema_extras.dart`); the use case calls [insert] inside its
/// transaction together with the stock movements.
final class DriftReturnRepository
    implements ReturnRepository, InvoiceReturnLookup, InvoiceReturnGuard {
  /// Creates the repository.
  const DriftReturnRepository(this._db);

  final AppDatabase _db;

  _Tables _tables(InvoiceKind kind) => switch (kind) {
    InvoiceKind.sales => _Tables(
      kind: kind,
      header: 'sales_returns',
      items: 'sales_return_items',
      partyColumn: 'customer_id',
      partyNameColumn: 'customer_name',
      headerTable: _db.salesReturns,
      itemTable: _db.salesReturnItems,
    ),
    InvoiceKind.purchase => _Tables(
      kind: kind,
      header: 'purchase_returns',
      items: 'purchase_return_items',
      partyColumn: 'supplier_id',
      partyNameColumn: 'supplier_name',
      headerTable: _db.purchaseReturns,
      itemTable: _db.purchaseReturnItems,
    ),
  };

  @override
  Future<Result<List<ReturnSummary>>> search(ReturnFilter filter) =>
      guardDatabase(() async {
        final kinds = filter.kind == null
            ? InvoiceKind.values
            : [filter.kind!];
        final found = <({ReturnSummary summary, int createdAt})>[];
        for (final kind in kinds) {
          final t = _tables(kind);
          final where = <String>[];
          final variables = <Variable<Object>>[];
          final invoiceId = filter.invoiceId;
          if (invoiceId != null) {
            where.add('r.invoice_id = ?');
            variables.add(Variable.withString(invoiceId));
          }
          final text = filter.query.trim().toLowerCase();
          if (text.isNotEmpty) {
            final pattern = '%${_escapeLike(text)}%';
            where.add(
              "(lower(r.number) LIKE ? ESCAPE '\\' "
              "OR lower(r.invoice_number) LIKE ? ESCAPE '\\' "
              "OR lower(r.${t.partyNameColumn}) LIKE ? ESCAPE '\\')",
            );
            variables.addAll([
              Variable.withString(pattern),
              Variable.withString(pattern),
              Variable.withString(pattern),
            ]);
          }
          final rows = await _db
              .customSelect(
                'SELECT r.id, r.number, r.invoice_id, r.invoice_number, '
                'r.${t.partyNameColumn} AS party_name, r.return_date, '
                'r.currency_code, r.decimal_places, r.total_minor, '
                'r.refund_amount_minor, r.created_at, '
                '(SELECT COUNT(*) FROM ${t.items} i '
                'WHERE i.return_id = r.id) AS line_count '
                'FROM ${t.header} r '
                '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
                'ORDER BY r.return_date DESC, r.created_at DESC, r.id DESC',
                variables: variables,
                readsFrom: {t.headerTable, t.itemTable},
              )
              .get();
          for (final row in rows) {
            Money money(int minor) => Money.fromMinor(
              minor,
              currencyCode: row.read<String>('currency_code'),
              decimalPlaces: row.read<int>('decimal_places'),
            );
            found.add((
              summary: ReturnSummary(
                id: row.read<String>('id'),
                kind: kind,
                number: row.read<String>('number'),
                invoiceId: row.read<String>('invoice_id'),
                invoiceNumber: row.read<String>('invoice_number'),
                partyName: row.read<String>('party_name'),
                returnDate: fromEpochMs(row.read<int>('return_date')),
                total: money(row.read<int>('total_minor')),
                refundAmount: money(row.read<int>('refund_amount_minor')),
                lineCount: row.read<int>('line_count'),
              ),
              createdAt: row.read<int>('created_at'),
            ));
          }
        }
        found.sort((a, b) {
          final byDate = b.summary.returnDate.compareTo(a.summary.returnDate);
          return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
        });
        return [for (final f in found) f.summary];
      });

  @override
  Future<Result<ReturnDocument>> getById(InvoiceKind kind, String id) =>
      guardDatabase(() async {
        final t = _tables(kind);
        final rows = await _loadHeaders(t, 'r.id = ?', [id]);
        if (rows.isEmpty) {
          throw const FailureException(NotFoundFailure('Return not found.'));
        }
        return rows.first;
      });

  @override
  Future<Result<ReturnDocument?>> findByIdempotencyKey(
    InvoiceKind kind,
    String key,
  ) => guardDatabase(() async {
    final rows = await _loadHeaders(
      _tables(kind),
      'r.idempotency_key = ?',
      [key],
    );
    return rows.isEmpty ? null : rows.first;
  });

  @override
  Future<Result<List<ReturnDocument>>> forInvoice(
    InvoiceKind kind,
    String invoiceId,
  ) => guardDatabase(
    () => _loadHeaders(_tables(kind), 'r.invoice_id = ?', [invoiceId]),
  );

  @override
  Future<Result<void>> insert(ReturnDocument d) => guardDatabase(() async {
    final t = _tables(d.kind);
    final refund = d.refund;
    await _db.customInsert(
      'INSERT INTO ${t.header} (id, number, invoice_id, invoice_number, '
      '${t.partyColumn}, ${t.partyNameColumn}, return_date, reason, notes, '
      'currency_code, decimal_places, net_total_minor, tax_total_minor, '
      'total_minor, refund_amount_minor, refund_method_id, '
      'refund_method_name, refund_reference, idempotency_key, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      variables: [
        Variable.withString(d.id),
        Variable.withString(d.number),
        Variable.withString(d.invoiceId),
        Variable.withString(d.invoiceNumber),
        Variable<String>(d.partyId),
        Variable.withString(d.partyName),
        Variable.withInt(toEpochMs(d.returnDate)),
        Variable.withString(d.reason),
        Variable<String>(d.notes),
        Variable.withString(d.net.currencyCode),
        Variable.withInt(d.net.decimalPlaces),
        Variable.withInt(d.net.minorUnits),
        Variable.withInt(d.tax.minorUnits),
        Variable.withInt(d.total.minorUnits),
        Variable.withInt(d.refundAmount.minorUnits),
        Variable<String>(refund?.methodId),
        Variable<String>(refund?.methodName),
        Variable<String>(refund?.reference),
        Variable.withString(d.idempotencyKey),
        Variable.withInt(toEpochMs(d.createdAt)),
      ],
      updates: {t.headerTable},
    );
    for (final line in d.lines) {
      final sales = d.kind == InvoiceKind.sales;
      await _db.customInsert(
        'INSERT INTO ${t.items} (id, return_id, line_no, invoice_item_id, '
        'product_id, product_name, sku, unit_symbol, unit_decimal_places, '
        'quantity_milli, net_minor, tax_minor, total_minor, '
        '${sales ? 'restocked, ' : ''}stock_cost_minor, note) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
        '${sales ? '?, ' : ''}?, ?)',
        variables: [
          Variable.withString(line.id),
          Variable.withString(d.id),
          Variable.withInt(line.lineNo),
          Variable.withString(line.invoiceLineId),
          Variable.withString(line.productId),
          Variable.withString(line.productName),
          Variable.withString(line.sku),
          Variable.withString(line.unitSymbol),
          Variable.withInt(line.unitDecimalPlaces),
          Variable.withInt(line.quantity.milli),
          Variable.withInt(line.net.minorUnits),
          Variable.withInt(line.tax.minorUnits),
          Variable.withInt(line.total.minorUnits),
          if (sales) Variable.withInt(line.restocked ? 1 : 0),
          Variable.withInt(line.stockCost.minorUnits),
          Variable<String>(line.note),
        ],
        updates: {t.itemTable},
      );
    }
  });

  @override
  Future<Result<Map<String, InvoiceReturnTotals>>> totalsFor(
    InvoiceKind kind,
    Iterable<String> invoiceIds,
  ) => guardDatabase(() async {
    final t = _tables(kind);
    final result = <String, InvoiceReturnTotals>{};
    final ids = invoiceIds.toSet().toList();
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT invoice_id, SUM(total_minor) AS returned, '
            'SUM(refund_amount_minor) AS refunded, COUNT(*) AS cnt '
            'FROM ${t.header} WHERE invoice_id IN ($marks) '
            'GROUP BY invoice_id',
            variables: [for (final id in chunk) Variable.withString(id)],
            readsFrom: {t.headerTable},
          )
          .get();
      for (final row in rows) {
        result[row.read<String>('invoice_id')] = InvoiceReturnTotals(
          returnedMinor: row.read<int>('returned'),
          refundedMinor: row.read<int>('refunded'),
          count: row.read<int>('cnt'),
        );
      }
    }
    return result;
  });

  @override
  Future<Result<PartyReturnTotals>> partyTotals(
    InvoiceKind kind,
    String partyId, {
    required String currencyCode,
    required int decimalPlaces,
  }) => guardDatabase(() async {
    final t = _tables(kind);
    final row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(total_minor), 0) AS returned, '
          'COALESCE(SUM(refund_amount_minor), 0) AS refunded '
          'FROM ${t.header} WHERE ${t.partyColumn} = ? '
          'AND currency_code = ? AND decimal_places = ?',
          variables: [
            Variable.withString(partyId),
            Variable.withString(currencyCode),
            Variable.withInt(decimalPlaces),
          ],
          readsFrom: {t.headerTable},
        )
        .getSingle();
    return PartyReturnTotals(
      returnedMinor: row.read<int>('returned'),
      refundedMinor: row.read<int>('refunded'),
    );
  });

  @override
  Future<Result<bool>> hasReturns(InvoiceKind kind, String invoiceId) =>
      guardDatabase(() async {
        final t = _tables(kind);
        final row = await _db
            .customSelect(
              'SELECT COUNT(*) AS cnt FROM ${t.header} WHERE invoice_id = ?',
              variables: [Variable.withString(invoiceId)],
              readsFrom: {t.headerTable},
            )
            .getSingle();
        return row.read<int>('cnt') > 0;
      });

  /// Headers matching [where] (an SQL condition on alias `r`), oldest
  /// first, each with its lines.
  Future<List<ReturnDocument>> _loadHeaders(
    _Tables t,
    String where,
    List<String> args,
  ) async {
    final headers = await _db
        .customSelect(
          'SELECT r.* FROM ${t.header} r WHERE $where '
          'ORDER BY r.created_at ASC, r.id ASC',
          variables: [for (final a in args) Variable.withString(a)],
          readsFrom: {t.headerTable},
        )
        .get();
    final documents = <ReturnDocument>[];
    for (final h in headers) {
      final id = h.read<String>('id');
      final currency = h.read<String>('currency_code');
      final places = h.read<int>('decimal_places');
      Money money(int minor) => Money.fromMinor(
        minor,
        currencyCode: currency,
        decimalPlaces: places,
      );
      final itemRows = await _db
          .customSelect(
            'SELECT * FROM ${t.items} WHERE return_id = ? ORDER BY line_no',
            variables: [Variable.withString(id)],
            readsFrom: {t.itemTable},
          )
          .get();
      final methodId = h.readNullable<String>('refund_method_id');
      final refundMinor = h.read<int>('refund_amount_minor');
      documents.add(
        ReturnDocument(
          id: id,
          kind: t.kind,
          number: h.read<String>('number'),
          invoiceId: h.read<String>('invoice_id'),
          invoiceNumber: h.read<String>('invoice_number'),
          partyId: h.readNullable<String>(t.partyColumn),
          partyName: h.read<String>(t.partyNameColumn),
          returnDate: fromEpochMs(h.read<int>('return_date')),
          reason: h.read<String>('reason'),
          notes: h.readNullable<String>('notes'),
          idempotencyKey: h.read<String>('idempotency_key'),
          createdAt: fromEpochMs(h.read<int>('created_at')),
          refund: methodId == null
              ? null
              : ReturnRefund(
                  amount: money(refundMinor),
                  methodId: methodId,
                  methodName: h.read<String>('refund_method_name'),
                  reference: h.readNullable<String>('refund_reference'),
                ),
          lines: [
            for (final r in itemRows)
              ReturnLine(
                id: r.read<String>('id'),
                lineNo: r.read<int>('line_no'),
                invoiceLineId: r.read<String>('invoice_item_id'),
                productId: r.read<String>('product_id'),
                productName: r.read<String>('product_name'),
                sku: r.read<String>('sku'),
                unitSymbol: r.read<String>('unit_symbol'),
                unitDecimalPlaces: r.read<int>('unit_decimal_places'),
                quantity: Quantity.fromMilli(r.read<int>('quantity_milli')),
                net: money(r.read<int>('net_minor')),
                tax: money(r.read<int>('tax_minor')),
                // Purchase returns always take the goods out of stock and
                // have no `restocked` column.
                restocked: t.kind == InvoiceKind.purchase
                    ? true
                    : r.read<int>('restocked') == 1,
                stockCost: money(r.read<int>('stock_cost_minor')),
                note: r.readNullable<String>('note'),
              ),
          ],
        ),
      );
    }
    return documents;
  }

  static String _escapeLike(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

/// Table and column names of one kind of return.
final class _Tables {
  const _Tables({
    required this.kind,
    required this.header,
    required this.items,
    required this.partyColumn,
    required this.partyNameColumn,
    required this.headerTable,
    required this.itemTable,
  });

  final InvoiceKind kind;
  final String header;
  final String items;
  final String partyColumn;
  final String partyNameColumn;
  final TableInfo<Table, Object?> headerTable;
  final TableInfo<Table, Object?> itemTable;
}
