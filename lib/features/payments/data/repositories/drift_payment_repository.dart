import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/payments/data/mappers/payment_mapper.dart';
import 'package:inventrix/features/payments/domain/entities/invoice_settlement.dart';
import 'package:inventrix/features/payments/domain/entities/party_payment_totals.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment.dart';
import 'package:inventrix/features/payments/domain/entities/payment_allocation.dart';
import 'package:inventrix/features/payments/domain/entities/payment_filter.dart';
import 'package:inventrix/features/payments/domain/entities/payment_reversal.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_repository.dart';
import 'package:inventrix/shared/domain/enums/invoice_kind.dart';
import 'package:inventrix/shared/domain/services/invoice_payment_guard.dart';

/// Drift/SQLite implementation of [PaymentRepository]. Also answers the
/// [InvoicePaymentGuard] questions the sales and purchase features ask.
///
/// Reads and writes are plain statements: the use cases wrap them in a
/// `TransactionRunner` action, so a failure part-way rolls everything back.
final class DriftPaymentRepository
    implements PaymentRepository, InvoicePaymentGuard {
  /// Creates the repository.
  const DriftPaymentRepository(this._db);

  final AppDatabase _db;

  static const int _chunk = 500;

  static const String _notReversed =
      'NOT EXISTS (SELECT 1 FROM payment_reversals r '
      'WHERE r.payment_id = p.id)';

  @override
  Future<Result<Payment?>> findByIdempotencyKey(String key) =>
      guardDatabase(() async {
        final row = await (_db.select(
          _db.payments,
        )..where((t) => t.idempotencyKey.equals(key))).getSingleOrNull();
        if (row == null) {
          return null;
        }
        return (await _hydrate([row])).single;
      });

  @override
  Future<Result<Payment>> getById(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.payments,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw const FailureException(NotFoundFailure('Payment not found.'));
    }
    return (await _hydrate([row])).single;
  });

  @override
  Future<Result<List<Payment>>> search(PaymentFilter filter) =>
      guardDatabase(() async {
        final where = <String>[];
        final variables = <Variable<Object>>[];
        final partyType = filter.partyType;
        if (partyType != null) {
          where.add('p.party_type = ?');
          variables.add(Variable.withString(partyType.dbName));
        }
        final partyId = filter.partyId;
        if (partyId != null) {
          where.add('(p.customer_id = ? OR p.supplier_id = ?)');
          variables
            ..add(Variable.withString(partyId))
            ..add(Variable.withString(partyId));
        }
        final kind = filter.kind;
        if (kind != null) {
          where.add('p.kind = ?');
          variables.add(Variable.withString(kind.dbName));
        }
        final invoiceId = filter.invoiceId;
        if (invoiceId != null) {
          where.add(
            'EXISTS (SELECT 1 FROM payment_allocations a '
            'WHERE a.payment_id = p.id AND '
            '(a.sales_invoice_id = ? OR a.purchase_invoice_id = ?))',
          );
          variables
            ..add(Variable.withString(invoiceId))
            ..add(Variable.withString(invoiceId));
        }
        if (!filter.includeReversed) {
          where.add(_notReversed);
        }
        final text = filter.query.trim().toLowerCase();
        if (text.isNotEmpty) {
          final pattern = '%${_escapeLike(text)}%';
          where.add(
            "(lower(p.number) LIKE ? ESCAPE '\\' "
            "OR lower(p.party_name) LIKE ? ESCAPE '\\' "
            "OR lower(p.method_name) LIKE ? ESCAPE '\\' "
            "OR lower(COALESCE(p.reference, '')) LIKE ? ESCAPE '\\')",
          );
          for (var i = 0; i < 4; i++) {
            variables.add(Variable.withString(pattern));
          }
        }
        final ids = await _db
            .customSelect(
              'SELECT p.id FROM payments p '
              '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
              'ORDER BY p.payment_date DESC, p.created_at DESC, p.id DESC',
              variables: variables,
              readsFrom: {_db.payments, _db.paymentAllocations},
            )
            .map((row) => row.read<String>('id'))
            .get();
        if (ids.isEmpty) {
          return <Payment>[];
        }
        final rows = <PaymentRow>[];
        for (final chunk in _chunks(ids)) {
          rows.addAll(
            await (_db.select(
              _db.payments,
            )..where((t) => t.id.isIn(chunk))).get(),
          );
        }
        final byId = {
          for (final p in await _hydrate(rows)) p.id: p,
        };
        return [for (final id in ids) byId[id]!];
      });

  @override
  Future<Result<List<Payment>>> activeRefundsOf(String paymentId) =>
      guardDatabase(() async {
        final rows = await _db
            .customSelect(
              'SELECT p.id FROM payments p '
              'WHERE p.refund_of_payment_id = ? AND $_notReversed '
              'ORDER BY p.created_at, p.id',
              variables: [Variable.withString(paymentId)],
              readsFrom: {_db.payments, _db.paymentReversals},
            )
            .map((row) => row.read<String>('id'))
            .get();
        if (rows.isEmpty) {
          return <Payment>[];
        }
        final headers = await (_db.select(
          _db.payments,
        )..where((t) => t.id.isIn(rows))).get();
        return _hydrate(headers);
      });

  @override
  Future<Result<void>> insert(Payment payment) => guardDatabase(() async {
    await _db.into(_db.payments).insert(paymentToCompanion(payment));
    for (final allocation in payment.allocations) {
      await _db
          .into(_db.paymentAllocations)
          .insert(allocationToCompanion(allocation));
    }
  });

  @override
  Future<Result<void>> insertAllocations(
    List<PaymentAllocation> allocations,
  ) => guardDatabase(() async {
    for (final allocation in allocations) {
      await _db
          .into(_db.paymentAllocations)
          .insert(allocationToCompanion(allocation));
    }
  });

  @override
  Future<Result<void>> insertReversal(PaymentReversal reversal) =>
      guardDatabase(() async {
        await _db
            .into(_db.paymentReversals)
            .insert(reversalToCompanion(reversal));
      });

  @override
  Future<Result<Map<String, InvoiceSettlement>>> settlements(
    InvoiceKind kind,
    Iterable<String> invoiceIds,
  ) => guardDatabase(() async {
    final column = _invoiceColumn(kind);
    final result = <String, InvoiceSettlement>{};
    for (final chunk in _chunks(invoiceIds.toSet().toList())) {
      final marks = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT a.$column AS invoice_id, '
            'SUM(a.amount_minor) AS net, '
            'SUM(CASE WHEN a.amount_minor < 0 THEN -a.amount_minor ELSE 0 END) '
            'AS refunded, COUNT(*) AS cnt '
            'FROM payment_allocations a '
            'WHERE a.$column IN ($marks) AND a.payment_id NOT IN '
            '(SELECT payment_id FROM payment_reversals) '
            'GROUP BY a.$column',
            variables: [for (final id in chunk) Variable.withString(id)],
            readsFrom: {_db.paymentAllocations, _db.paymentReversals},
          )
          .get();
      for (final row in rows) {
        result[row.read<String>('invoice_id')] = InvoiceSettlement(
          netPaidMinor: row.read<int>('net'),
          refundedMinor: row.read<int>('refunded'),
          activeCount: row.read<int>('cnt'),
        );
      }
    }
    return result;
  });

  @override
  Future<Result<PartyPaymentTotals>> partyTotals(
    PartyType type,
    String partyId, {
    required String currencyCode,
    required int decimalPlaces,
  }) => guardDatabase(() async {
    final column = type == PartyType.customer ? 'customer_id' : 'supplier_id';
    final row = await _db
        .customSelect(
          "SELECT COALESCE(SUM(CASE WHEN p.kind = 'payment' "
          'THEN p.amount_minor ELSE 0 END), 0) AS paid, '
          "COALESCE(SUM(CASE WHEN p.kind = 'refund' "
          'THEN p.amount_minor ELSE 0 END), 0) AS refunded '
          'FROM payments p '
          'WHERE p.$column = ? AND p.currency_code = ? '
          'AND p.decimal_places = ? AND $_notReversed',
          variables: [
            Variable.withString(partyId),
            Variable.withString(currencyCode),
            Variable.withInt(decimalPlaces),
          ],
          readsFrom: {_db.payments, _db.paymentReversals},
        )
        .getSingle();
    return PartyPaymentTotals(
      paymentsMinor: row.read<int>('paid'),
      refundsMinor: row.read<int>('refunded'),
    );
  });

  @override
  Future<Result<bool>> hasActivePayments(InvoiceKind kind, String invoiceId) =>
      guardDatabase(() async {
        final column = _invoiceColumn(kind);
        final row = await _db
            .customSelect(
              'SELECT COUNT(*) AS cnt FROM payment_allocations a '
              'WHERE a.$column = ? AND a.payment_id NOT IN '
              '(SELECT payment_id FROM payment_reversals)',
              variables: [Variable.withString(invoiceId)],
              readsFrom: {_db.paymentAllocations, _db.paymentReversals},
            )
            .getSingle();
        return row.read<int>('cnt') > 0;
      });

  Future<List<Payment>> _hydrate(List<PaymentRow> rows) async {
    if (rows.isEmpty) {
      return [];
    }
    final ids = [for (final r in rows) r.id];
    final allocations = <PaymentAllocationRow>[];
    final reversals = <PaymentReversalRow>[];
    for (final chunk in _chunks(ids)) {
      allocations.addAll(
        await (_db.select(_db.paymentAllocations)
              ..where((t) => t.paymentId.isIn(chunk))
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get(),
      );
      reversals.addAll(
        await (_db.select(
          _db.paymentReversals,
        )..where((t) => t.paymentId.isIn(chunk))).get(),
      );
    }
    return [
      for (final row in rows)
        paymentFromRows(
          row,
          allocations.where((a) => a.paymentId == row.id).toList(),
          reversals.where((r) => r.paymentId == row.id).firstOrNull,
        ),
    ];
  }

  static String _invoiceColumn(InvoiceKind kind) =>
      kind == InvoiceKind.sales ? 'sales_invoice_id' : 'purchase_invoice_id';

  static Iterable<List<String>> _chunks(List<String> ids) sync* {
    for (var i = 0; i < ids.length; i += _chunk) {
      yield ids.sublist(i, i + _chunk > ids.length ? ids.length : i + _chunk);
    }
  }

  static String _escapeLike(String text) => text
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}
