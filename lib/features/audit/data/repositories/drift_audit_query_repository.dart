import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/audit/data/repositories/drift_audit_event_repository.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_query.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_query_repository.dart';

/// Drift implementation of [AuditQueryRepository].
final class DriftAuditQueryRepository implements AuditQueryRepository {
  /// Creates the repository.
  const DriftAuditQueryRepository(this._db);

  final AppDatabase _db;

  static String _like(String text) {
    final escaped = text
        .toLowerCase()
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return '%$escaped%';
  }

  @override
  Future<Result<List<AuditEvent>>> search(AuditEventFilter f) =>
      guardDatabase(() async {
        final where = <String>[];
        final vars = <Variable<Object>>[];
        final search = f.search.trim();
        if (search.isNotEmpty) {
          where.add(
            "(lower(event_type) LIKE ? ESCAPE '\\' OR lower(entity_id) LIKE ? "
            "ESCAPE '\\' OR lower(COALESCE(reason, '')) LIKE ? ESCAPE '\\' "
            "OR lower(actor_display_name) LIKE ? ESCAPE '\\' OR "
            "lower(COALESCE(metadata, '')) LIKE ? ESCAPE '\\' OR "
            "lower(COALESCE(new_values, '')) LIKE ? ESCAPE '\\' OR "
            "lower(COALESCE(previous_values, '')) LIKE ? ESCAPE '\\')",
          );
          vars.addAll(List.filled(7, Variable<String>(_like(search))));
        }
        final reference = f.reference.trim();
        if (reference.isNotEmpty) {
          where.add(
            "(lower(entity_id) LIKE ? ESCAPE '\\' OR "
            "lower(COALESCE(metadata, '')) LIKE ? ESCAPE '\\')",
          );
          vars.addAll(List.filled(2, Variable<String>(_like(reference))));
        }
        final actor = f.actor.trim();
        if (actor.isNotEmpty) {
          where.add("lower(actor_display_name) LIKE ? ESCAPE '\\'");
          vars.add(Variable<String>(_like(actor)));
        }
        if (f.from != null) {
          final from = DateTime.utc(f.from!.year, f.from!.month, f.from!.day);
          where.add('occurred_at_utc >= ?');
          vars.add(Variable<int>(from.millisecondsSinceEpoch));
        }
        if (f.to != null) {
          final to = DateTime.utc(f.to!.year, f.to!.month, f.to!.day)
              .add(const Duration(days: 1));
          where.add('occurred_at_utc < ?');
          vars.add(Variable<int>(to.millisecondsSinceEpoch));
        }
        if (f.eventType != null) {
          where.add('event_type = ?');
          vars.add(Variable<String>(f.eventType!));
        }
        if (f.entityType != null) {
          where.add('entity_type = ?');
          vars.add(Variable<String>(f.entityType!));
        }
        final rows = await _db
            .customSelect(
              'SELECT * FROM audit_events '
              '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
              'ORDER BY seq DESC LIMIT ? OFFSET ?',
              variables: [...vars, Variable<int>(f.limit), Variable<int>(f.offset)],
              readsFrom: {_db.auditEvents},
            )
            .map((r) => DriftAuditEventRepository.map(_db.auditEvents.map(r.data)))
            .get();
        return rows;
      });

  @override
  Future<Result<AuditStats>> stats({int recentLimit = 10}) =>
      guardDatabase(() async {
        Future<int> count(String where) async => (await _db
            .customSelect('SELECT COUNT(*) AS c FROM audit_events WHERE $where')
            .getSingle()).read<int>('c');
        final total = await count('1 = 1');
        final types = await _db
            .customSelect(
              'SELECT event_type AS t, COUNT(*) AS c FROM audit_events '
              'GROUP BY event_type ORDER BY c DESC, t ASC',
            )
            .get();
        final recent = await (_db.select(_db.auditEvents)
              ..orderBy([(t) => OrderingTerm.desc(t.seq)])
              ..limit(recentLimit))
            .get();
        return AuditStats(
          totalEvents: total,
          byType: {for (final r in types) r.read<String>('t'): r.read<int>('c')},
          cancelledDocuments: await count("action IN ('voided', 'cancelled')"),
          reversedPayments: await count("action = 'reversed'"),
          taxConfigurationChanges: await count(
            "(entity_type LIKE 'tax\\_%' ESCAPE '\\' OR "
            "json_extract(metadata, '\$.taxTreatmentChanged') = 1)",
          ),
          stockAdjustments: await count("entity_type = 'stock'"),
          dataExports: await count("event_type = 'data_export.created'"),
          recent: recent.map(DriftAuditEventRepository.map).toList(),
        );
      });

  @override
  Future<Result<AuditEvent?>> byId(String id) => guardDatabase(() async {
    final row = await (_db.select(
      _db.auditEvents,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : DriftAuditEventRepository.map(row);
  });

  @override
  Future<Result<List<AuditEvent>>> byCorrelation(String correlationId) =>
      guardDatabase(() async {
        final rows = await (_db.select(_db.auditEvents)
              ..where((t) => t.correlationId.equals(correlationId))
              ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
            .get();
        return rows.map(DriftAuditEventRepository.map).toList();
      });

  @override
  Future<Result<List<String>>> eventTypes() => guardDatabase(() async {
    final rows = await _db
        .customSelect('SELECT DISTINCT event_type AS t FROM audit_events ORDER BY t')
        .get();
    return [for (final r in rows) r.read<String>('t')];
  });

  @override
  Future<Result<List<String>>> entityTypes() => guardDatabase(() async {
    final rows = await _db
        .customSelect('SELECT DISTINCT entity_type AS t FROM audit_events ORDER BY t')
        .get();
    return [for (final r in rows) r.read<String>('t')];
  });
}
