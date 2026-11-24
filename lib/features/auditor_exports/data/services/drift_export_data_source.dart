import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/auditor_exports/data/services/export_queries.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_table.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';

/// Reads export data from the live database inside one transaction, so every
/// dataset comes from the same consistent state. Only SELECT statements are
/// run against the business tables; the only thing created is a temporary
/// view (connection-local, never written to the database file) that is used
/// to learn the column names of an empty result.
final class DriftExportDataSource implements ExportDataSource {
  /// Creates the data source.
  const DriftExportDataSource(this._db);

  final AppDatabase _db;

  @override
  Future<Result<T>> inSnapshot<T>(
    Future<T> Function(ExportSnapshot snapshot) action,
  ) => guardDatabase(
    () => _db.transaction(() => action(_DriftExportSnapshot(_db))),
  );
}

final class _DriftExportSnapshot implements ExportSnapshot {
  const _DriftExportSnapshot(this._db);

  final AppDatabase _db;

  @override
  Future<List<ExportTable>> tables(
    ExportDataset dataset,
    ExportPeriod period,
  ) async {
    final tables = <ExportTable>[];
    for (final query in ExportQueries.forDataset(dataset, period)) {
      final rows = await _db
          .customSelect(query.sql, variables: query.variables)
          .get();
      final headers = rows.isEmpty
          ? await _columns(query)
          : rows.first.data.keys.toList();
      tables.add(
        ExportTable(
          path: query.path,
          headers: headers,
          rows: [
            for (final row in rows)
              [for (final h in headers) _cell(h, row.data[h])],
          ],
        ),
      );
    }
    return tables;
  }

  @override
  Future<int> schemaVersion() async {
    final row = await _db.customSelect('PRAGMA user_version').getSingle();
    return row.read<int>('user_version');
  }

  @override
  Future<List<ExportAttachment>> attachments(ExportPeriod period) async {
    final q = ExportQueries.attachmentRefs(period);
    final rows = await _db.customSelect(q.sql, variables: q.variables).get();
    return [
      for (final r in rows)
        ExportAttachment(
          id: r.read<String>('id'),
          ownerType: r.read<String>('owner_type'),
          ownerId: r.read<String>('owner_id'),
          fileName: r.read<String>('file_name'),
          storedPath: r.read<String>('stored_path'),
        ),
    ];
  }

  @override
  Future<List<ExportInvoiceRef>> salesInvoices(ExportPeriod period) async {
    final q = ExportQueries.invoiceRefs(period);
    final rows = await _db.customSelect(q.sql, variables: q.variables).get();
    return [
      for (final r in rows)
        ExportInvoiceRef(
          id: r.read<String>('id'),
          number: r.read<String>('number'),
        ),
    ];
  }

  /// Column names of [query] even when it returns no rows, through a
  /// temporary view.
  Future<List<String>> _columns(ExportQuery query) async {
    var sql = query.sql;
    for (final v in query.variables) {
      sql = sql.replaceFirst('?', '${v.value}');
    }
    await _db.customStatement('DROP VIEW IF EXISTS temp.export_probe');
    await _db.customStatement('CREATE TEMP VIEW export_probe AS $sql');
    try {
      final info = await _db.customSelect('PRAGMA table_info(export_probe)').get();
      return [for (final r in info) r.read<String>('name')];
    } finally {
      await _db.customStatement('DROP VIEW IF EXISTS temp.export_probe');
    }
  }

  /// Epoch columns become readable text: `*_date` and `effective_*` as
  /// `yyyy-MM-dd`, `*_at` and `*_at_utc` as ISO 8601 UTC. Everything else
  /// is exported exactly as stored.
  static Object? _cell(String header, Object? value) {
    if (value is! int) {
      return value is List<int> ? null : value;
    }
    final isDate =
        header.endsWith('_date') ||
        header == 'effective_from' ||
        header == 'effective_until';
    final isTime = header.endsWith('_at') || header.endsWith('_at_utc');
    if (!isDate && !isTime) {
      return value;
    }
    final time = DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    if (isDate) {
      return '${time.year.toString().padLeft(4, '0')}-'
          '${time.month.toString().padLeft(2, '0')}-'
          '${time.day.toString().padLeft(2, '0')}';
    }
    return time.toIso8601String();
  }
}
