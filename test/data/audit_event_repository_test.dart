import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/features/audit/data/repositories/audit_event_log_repository.dart';
import 'package:inventrix/features/audit/data/repositories/drift_audit_event_repository.dart';
import 'package:inventrix/features/audit/data/services/settings_audit_actor_provider.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/entities/audit_verification.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';
import 'package:inventrix/features/audit/domain/usecases/verify_audit_chain.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';
import 'package:inventrix/shared/domain/audit/audit_entry.dart';

import '../features/audit/audit_test_support.dart';

/// Real schema (in-memory SQLite). Written without a Flutter SDK: not yet
/// executed.
void main() {
  late AppDatabase db;
  late DriftAuditEventRepository repo;
  late AuditRecorder recorder;
  late VerifyAuditChain verify;

  Future<int> count(String table) async => (await db
      .customSelect('SELECT COUNT(*) AS c FROM $table')
      .getSingle()).read<int>('c');

  Future<void> record(String entityId, {Map<String, Object?>? after}) async {
    final r = await recorder.record(draft(entityId: entityId, after: after));
    expect(r.isSuccess, isTrue, reason: r.failureOrNull?.toString());
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    repo = DriftAuditEventRepository(db);
    recorder = AuditRecorder(
      repository: repo,
      actors: SettingsAuditActorProvider(db),
      hasher: hasher,
      clock: StepClock(),
      ids: CountingIds(),
    );
    verify = VerifyAuditChain(repository: repo, hasher: hasher, pageSize: 2);
  });

  tearDown(() => db.close());

  test('events are stored in a verifiable chain', () async {
    for (var i = 0; i < 5; i++) {
      await record('p$i', after: {'n': i, 'name': 'Item $i'});
    }
    expect(await count('audit_events'), 6);
    final v = (await verify()).valueOrNull!;
    expect(v.isValid, isTrue);
    expect(v.eventsChecked, 6);
  });

  test('values survive a round trip and still hash correctly', () async {
    await record('p1', after: {'price': 12050, 'tags': ['a', 'b'], 'ok': true});
    final e = (await repo.latest()).valueOrNull!;
    expect(e.newValues, {'price': 12050, 'tags': ['a', 'b'], 'ok': true});
    expect(e.isHashValid(hasher), isTrue);
    expect(e.sequence, 2);
  });

  test('the genesis event notes how many legacy log rows exist', () async {
    await db.customStatement(
      "INSERT INTO audit_logs (id, entity_type, entity_id, action, summary, occurred_at) VALUES ('old1', 'sales_invoice', 's1', 'posted', 'Posted', 1)",
    );
    await record('p1');
    final first = (await repo.page(limit: 1)).valueOrNull!.single;
    expect(first.eventType, 'audit.chain_started');
    expect(first.metadata!['legacyLogCount'], 1);
  });

  group('append-only', () {
    test('UPDATE is refused by the database', () async {
      await record('p1');
      await expectLater(
        db.customStatement("UPDATE audit_events SET reason = 'x'"),
        throwsA(anything),
      );
    });

    test('DELETE is refused by the database', () async {
      await record('p1');
      await expectLater(
        db.customStatement('DELETE FROM audit_events'),
        throwsA(anything),
      );
      expect(await count('audit_events'), 2);
    });

    test('the same hash cannot be stored twice', () async {
      await record('p1');
      await expectLater(
        db.customStatement(
          'INSERT INTO audit_events (id, event_type, entity_type, entity_id, action, actor_type, actor_display_name, occurred_at_utc, source, correlation_id, previous_event_hash, event_hash, schema_version) '
          "SELECT 'dup', event_type, entity_type, entity_id, action, actor_type, actor_display_name, occurred_at_utc, source, correlation_id, previous_event_hash, event_hash, schema_version FROM audit_events WHERE seq = 2",
        ),
        throwsA(anything),
      );
    });
  });

  group('tampering by someone with direct database access', () {
    Future<void> disableTriggers() async {
      await db.customStatement('DROP TRIGGER trg_audit_events_no_update');
      await db.customStatement('DROP TRIGGER trg_audit_events_no_delete');
    }

    setUp(() async {
      for (var i = 0; i < 5; i++) {
        await record('p$i', after: {'n': i});
      }
    });

    test('editing an event is detected', () async {
      await disableTriggers();
      await db.customStatement(
        "UPDATE audit_events SET new_values = '{\"n\":999}' WHERE seq = 4",
      );
      final v = (await verify()).valueOrNull!;
      expect(v.problem, AuditProblem.hashMismatch);
      expect(v.problemSequence, 4);
    });

    test('removing a middle event is detected', () async {
      await disableTriggers();
      await db.customStatement('DELETE FROM audit_events WHERE seq = 3');
      final v = (await verify()).valueOrNull!;
      expect(v.problem, AuditProblem.brokenLink);
      expect(v.problemSequence, 4);
    });

    test('removing the newest events needs a retained checkpoint', () async {
      final checkpoint = (await CreateAuditCheckpoint(repository: repo, clock: StepClock())())
          .valueOrNull!;
      await disableTriggers();
      await db.customStatement('DELETE FROM audit_events WHERE seq > 4');
      expect((await verify()).valueOrNull!.isValid, isTrue);
      final v = (await verify(checkpoint: checkpoint)).valueOrNull!;
      expect(v.problem, AuditProblem.checkpointMissing);
    });
  });

  group('transactions', () {
    test('an audit event rolls back with a failed business operation', () async {
      final runner = DriftTransactionRunner(db, ids: CountingIds());
      final adapter = AuditEventLogRepository(
        recorder: recorder,
        events: repo,
        legacy: DriftAuditLogRepository(db),
      );
      final result = await runner.runResult<void>(() async {
        await db.customStatement(
          "INSERT INTO units (id, name, symbol, decimal_places, archived_at, created_at, updated_at) VALUES ('u9', 'Unit', 'u', 0, NULL, 1, 1)",
        );
        final audited = await adapter.record(
          AuditEntry(
            id: 'x',
            entityType: 'unit',
            entityId: 'u9',
            action: 'created',
            summary: 'Created unit',
            occurredAt: DateTime.utc(2026, 6, 1),
          ),
        );
        expect(audited.isSuccess, isTrue);
        throw StateError('the business operation fails after being audited');
      });
      expect(result.isFailure, isTrue);
      expect(await count('units'), 0);
      expect(await count('audit_events'), 0); // genesis rolled back too
    });

    test('a successful operation commits the change and its event together', () async {
      final runner = DriftTransactionRunner(db, ids: CountingIds());
      await runner.runResult<void>(() async {
        await db.customStatement(
          "INSERT INTO units (id, name, symbol, decimal_places, archived_at, created_at, updated_at) VALUES ('u9', 'Unit', 'u', 0, NULL, 1, 1)",
        );
        await record('u9');
      });
      expect(await count('units'), 1);
      expect(await count('audit_events'), 2);
    });

    test('events of one transaction share a correlation id', () async {
      final runner = DriftTransactionRunner(db, ids: CountingIds());
      await runner.runResult<void>(() async {
        await record('a');
        await record('b');
      });
      await record('c');
      final rows = await db
          .customSelect(
            "SELECT entity_id, correlation_id FROM audit_events WHERE entity_type = 'product' ORDER BY seq",
          )
          .get();
      final ids = {
        for (final r in rows)
          r.read<String>('entity_id'): r.read<String>('correlation_id'),
      };
      expect(ids['a'], ids['b']);
      expect(ids['c'], isNot(ids['a']));
    });

    test('concurrent recorders still produce one unbroken chain', () async {
      await Future.wait([for (var i = 0; i < 12; i++) recorder.record(draft(entityId: 'c$i'))]);
      final v = (await verify()).valueOrNull!;
      expect(v.isValid, isTrue);
      expect(v.eventsChecked, 13);
    });
  });

  group('actor', () {
    test('without an operator name the device is recorded', () async {
      await record('p1');
      final e = (await repo.latest()).valueOrNull!;
      expect(e.actor.type, AuditActorType.device);
      expect(e.actor.isVerified, isFalse);
    });

    test('a typed operator name is recorded as an unverified local operator', () async {
      await db.customStatement(
        "INSERT INTO app_settings (key, value, updated_at) VALUES ('audit_operator_name', 'Ravi', 1)",
      );
      await record('p1');
      final e = (await repo.latest()).valueOrNull!;
      expect(e.actor.type, AuditActorType.localOperator);
      expect(e.actor.displayName, 'Ravi');
      expect(e.actor.isVerified, isFalse);
    });
  });

  group('existing audit call sites (AuditLogRepository adapter)', () {
    late AuditEventLogRepository adapter;
    setUp(() {
      adapter = AuditEventLogRepository(
        recorder: recorder,
        events: repo,
        legacy: DriftAuditLogRepository(db),
      );
    });

    test('an old-style entry becomes a chained event with its summary', () async {
      final r = await adapter.record(
        AuditEntry(
          id: 'legacy-id',
          entityType: 'sales_invoice',
          entityId: 's1',
          action: 'voided',
          summary: 'Voided INV-1: wrong customer',
          occurredAt: DateTime.utc(2026, 6, 1, 12),
          reason: 'wrong customer',
        ),
      );
      expect(r.isSuccess, isTrue);
      final e = (await repo.latest()).valueOrNull!;
      expect(e.eventType, 'sales_invoice.voided');
      expect(e.reason, 'wrong customer');
      expect(e.metadata!['summary'], 'Voided INV-1: wrong customer');
      expect(e.occurredAtUtc, DateTime.utc(2026, 6, 1, 12));
      expect((await verify()).valueOrNull!.isValid, isTrue);
    });

    test('history for a record merges legacy rows and new events, newest first', () async {
      await db.customStatement(
        "INSERT INTO audit_logs (id, entity_type, entity_id, action, summary, occurred_at) VALUES ('old', 'sales_invoice', 's1', 'posted', 'Posted INV-1', ${DateTime.utc(2026, 6, 1, 9).millisecondsSinceEpoch})",
      );
      await adapter.record(
        AuditEntry(
          id: 'n',
          entityType: 'sales_invoice',
          entityId: 's1',
          action: 'voided',
          summary: 'Voided INV-1',
          occurredAt: DateTime.utc(2026, 6, 1, 12),
        ),
      );
      final history = (await adapter.forEntity('sales_invoice', 's1')).valueOrNull!;
      expect(history.map((e) => e.action), ['voided', 'posted']);
      expect(history.first.summary, 'Voided INV-1');
    });
  });

  test('the outbox is durable and flushes into the chain', () async {
    await repo.enqueue('q1', draft(entityId: 'late'), DateTime.utc(2026, 6, 1));
    expect((await repo.queued()).valueOrNull, hasLength(1));
    expect((await recorder.flushOutbox()).valueOrNull, 1);
    expect((await repo.queued()).valueOrNull, isEmpty);
    expect((await repo.latest()).valueOrNull!.entityId, 'late');
  });

  test('a local operator label is just a label', () {
    expect(AuditActor.localOperator('Ravi').isVerified, isFalse);
  });
}
