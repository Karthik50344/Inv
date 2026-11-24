import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/repositories/export_ports.dart';

/// Drift implementation of [ExportHistoryRepository].
final class DriftExportHistoryRepository implements ExportHistoryRepository {
  /// Creates the repository.
  const DriftExportHistoryRepository(this._db);

  final AppDatabase _db;

  ExportRecord _map(AuditExportHistoryRow r) => ExportRecord(
    id: r.id,
    name: r.name,
    createdAt: fromEpochMs(r.createdAt),
    period: _period(r),
    format: ExportFormat.parse(r.format),
    datasets: [
      for (final code in (jsonDecode(r.datasets) as List<Object?>).cast<String>())
        if (ExportDataset.tryParse(code) != null) ExportDataset.tryParse(code)!,
    ],
    fileName: r.fileName,
    sizeBytes: r.sizeBytes,
    sha256: r.sha256,
    integrityStatus: r.integrityStatus,
    chainStatus: r.chainStatus,
    appVersion: r.appVersion,
    schemaVersion: r.schemaVersion,
    verifiedAt: fromEpochMsOrNull(r.verifiedAt),
    fileDeletedAt: fromEpochMsOrNull(r.fileDeletedAt),
  );

  ExportPeriod _period(AuditExportHistoryRow r) {
    final kind = ExportPeriodKind.parse(r.periodKind);
    if (kind == ExportPeriodKind.all || r.periodFrom == null || r.periodTo == null) {
      return const ExportPeriod.all();
    }
    final from = DateTime.parse(r.periodFrom!);
    final to = DateTime.parse(r.periodTo!);
    return kind == ExportPeriodKind.custom
        ? ExportPeriod.custom(from, to)
        : ExportPeriod.financialYear(from.year, startMonth: from.month);
  }

  @override
  Future<Result<void>> add(ExportRecord record) => guardDatabase(
    () => _db
        .into(_db.auditExportHistory)
        .insert(
          AuditExportHistoryCompanion.insert(
            id: record.id,
            name: record.name,
            createdAt: toEpochMs(record.createdAt),
            periodKind: record.period.kind.code,
            periodLabel: record.period.label,
            periodFrom: Value(record.period.fromText),
            periodTo: Value(record.period.toText),
            format: record.format.code,
            datasets: jsonEncode([for (final d in record.datasets) d.code]),
            fileName: record.fileName,
            sizeBytes: record.sizeBytes,
            sha256: record.sha256,
            integrityStatus: record.integrityStatus,
            chainStatus: record.chainStatus,
            appVersion: record.appVersion,
            schemaVersion: record.schemaVersion,
            verifiedAt: Value(
              record.verifiedAt == null ? null : toEpochMs(record.verifiedAt!),
            ),
          ),
        ),
  );

  @override
  Future<Result<List<ExportRecord>>> list({int limit = 100}) =>
      guardDatabase(() async {
        final rows =
            await (_db.select(_db.auditExportHistory)
                  ..orderBy([
                    (t) => OrderingTerm.desc(t.createdAt),
                    (t) => OrderingTerm.desc(t.id),
                  ])
                  ..limit(limit))
                .get();
        return rows.map(_map).toList();
      });

  @override
  Future<Result<ExportRecord?>> getById(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.auditExportHistory,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _map(row);
  });

  @override
  Future<Result<void>> updateIntegrity(
    String id, {
    required String status,
    required DateTime at,
  }) => guardDatabase(
    () async =>
        (_db.update(_db.auditExportHistory)..where((t) => t.id.equals(id)))
            .write(
              AuditExportHistoryCompanion(
                integrityStatus: Value(status),
                verifiedAt: Value(toEpochMs(at)),
              ),
            ),
  );

  @override
  Future<Result<void>> markFileDeleted(String id, DateTime at) =>
      guardDatabase(
        () async =>
            (_db.update(_db.auditExportHistory)..where((t) => t.id.equals(id)))
                .write(
                  AuditExportHistoryCompanion(
                    fileDeletedAt: Value(toEpochMs(at)),
                  ),
                ),
      );
}
