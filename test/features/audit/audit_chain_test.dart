import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/services/audit_correlation.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_verification.dart';
import 'package:inventrix/features/audit/domain/services/audit_canonical.dart';
import 'package:inventrix/features/audit/domain/usecases/verify_audit_chain.dart';

import 'audit_test_support.dart';

void main() {
  group('canonical serialisation', () {
    test('keys are sorted and the text has no whitespace', () {
      expect(
        AuditCanonical.encode({'b': 1, 'a': {'d': 2, 'c': [3, 1]}}),
        '{"a":{"c":[3,1],"d":2},"b":1}',
      );
    });

    test('insertion order does not matter', () {
      expect(
        AuditCanonical.encode({'x': 1, 'y': 2}),
        AuditCanonical.encode({'y': 2, 'x': 1}),
      );
    });

    test('dates become ISO UTC text', () {
      expect(
        AuditCanonical.encode({'at': DateTime.utc(2026, 6, 1, 10)}),
        '{"at":"2026-06-01T10:00:00.000Z"}',
      );
    });

    test('unsupported values and non-finite numbers are rejected', () {
      expect(() => AuditCanonical.encode({'x': Object()}), throwsArgumentError);
      expect(() => AuditCanonical.encode({'x': double.nan}), throwsArgumentError);
    });
  });

  group('sealing', () {
    AuditEvent seal({
      String previous = '',
      String name = 'Ravi',
      String type = 'product.updated',
      Map<String, Object?>? after,
    }) => AuditEvent.seal(
      id: 'e1',
      eventType: type,
      entityType: 'product',
      entityId: 'p1',
      action: 'updated',
      actor: AuditActor.localOperator(name),
      occurredAtUtc: DateTime.utc(2026, 6, 1),
      source: 'app',
      correlationId: 'c1',
      previousEventHash: previous.isEmpty ? kAuditGenesisHash : previous,
      newValues: after,
      hasher: hasher,
    );

    test('the same fields always give the same 64-character hash', () {
      expect(seal().eventHash, seal().eventHash);
      expect(seal().eventHash, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('changing any field changes the hash', () {
      final base = seal().eventHash;
      expect(seal(name: 'Mala').eventHash, isNot(base));
      expect(seal(type: 'product.created').eventHash, isNot(base));
      expect(seal(after: {'name': 'X'}).eventHash, isNot(base));
      expect(seal(previous: 'a' * 64).eventHash, isNot(base));
    });

    test('the previous hash is part of the content', () {
      expect(seal().previousEventHash, kAuditGenesisHash);
    });

    test('a sealed event verifies, an altered copy does not', () {
      final e = seal(after: {'price': 100});
      expect(e.isHashValid(hasher), isTrue);
      final altered = AuditEvent.stored(
        id: e.id,
        eventType: e.eventType,
        entityType: e.entityType,
        entityId: e.entityId,
        action: e.action,
        actor: e.actor,
        occurredAtUtc: e.occurredAtUtc,
        source: e.source,
        correlationId: e.correlationId,
        previousEventHash: e.previousEventHash,
        eventHash: e.eventHash,
        schemaVersion: e.schemaVersion,
        newValues: {'price': 1},
      );
      expect(altered.isHashValid(hasher), isFalse);
    });
  });

  group('recorder', () {
    late MemoryAuditRepository repo;
    setUp(() => repo = MemoryAuditRepository()..legacyCount = 7);

    test('the first record starts the chain with a genesis event', () async {
      final recorder = recorderFor(repo);
      final r = await recorder.record(draft());
      expect(r.isSuccess, isTrue);
      expect(repo.events, hasLength(2));
      final genesis = repo.events.first;
      expect(genesis.eventType, 'audit.chain_started');
      expect(genesis.previousEventHash, kAuditGenesisHash);
      expect(genesis.metadata!['legacyLogCount'], 7);
      expect(genesis.actor, AuditActor.system);
      expect(repo.events.last.previousEventHash, genesis.eventHash);
    });

    test('events link to each other in order', () async {
      final recorder = recorderFor(repo);
      for (var i = 0; i < 4; i++) {
        await recorder.record(draft(entityId: 'p$i'));
      }
      for (var i = 1; i < repo.events.length; i++) {
        expect(repo.events[i].previousEventHash, repo.events[i - 1].eventHash);
        expect(repo.events[i].sequence, greaterThan(repo.events[i - 1].sequence!));
      }
    });

    test('actor, time, values and reason are recorded', () async {
      final clock = StepClock(DateTime.utc(2026, 6, 1, 9));
      final recorder = recorderFor(repo, clock: clock);
      await recorder.record(
        draft(before: {'price': 100}, after: {'price': 120}, reason: 'Supplier change'),
      );
      final e = repo.events.last;
      expect(e.actor.displayName, 'Ravi');
      expect(e.actor.isVerified, isFalse);
      expect(e.previousValues, {'price': 100});
      expect(e.newValues, {'price': 120});
      expect(e.reason, 'Supplier change');
      expect(e.occurredAtUtc.isUtc, isTrue);
    });

    test('with no operator the device is the actor, never a made-up user', () async {
      final recorder = recorderFor(repo, actor: AuditActor.device);
      await recorder.record(draft());
      expect(repo.events.last.actor.type, AuditActorType.device);
      expect(repo.events.last.actor.isVerified, isFalse);
    });

    test('events of one operation share a correlation id', () async {
      final recorder = recorderFor(repo);
      await AuditCorrelation.run('op-1', () async {
        await recorder.record(draft(entityId: 'a'));
        await recorder.record(draft(entityId: 'b'));
      });
      await recorder.record(draft(entityId: 'c'));
      final byEntity = {for (final e in repo.events) e.entityId: e.correlationId};
      expect(byEntity['a'], 'op-1');
      expect(byEntity['b'], 'op-1');
      expect(byEntity['c'], isNot('op-1'));
    });

    test('a nested correlation scope keeps the outer id', () async {
      final recorder = recorderFor(repo);
      await AuditCorrelation.run('outer', () async {
        await AuditCorrelation.run('inner', () => recorder.record(draft()));
      });
      expect(repo.events.last.correlationId, 'outer');
    });

    test('a value that cannot be serialised fails before touching storage', () async {
      final recorder = recorderFor(repo);
      final r = await recorder.record(draft(after: {'bad': Object()}));
      expect(r.failureOrNull, isA<AuditFailure>());
      expect(repo.events, isEmpty);
    });

    test('record is fail-closed: a storage failure is returned', () async {
      repo.failAppend = true;
      final r = await recorderFor(repo).record(draft());
      expect(r.isFailure, isTrue);
      expect(repo.events, isEmpty);
    });
  });

  group('outbox for work outside a transaction', () {
    late MemoryAuditRepository repo;
    setUp(() => repo = MemoryAuditRepository());

    test('a failed write is parked, then written later in order with its '
        'original time', () async {
      final clock = StepClock(DateTime.utc(2026, 6, 1, 8));
      final recorder = recorderFor(repo, clock: clock);
      repo.failAppend = true;
      expect((await recorder.recordOrQueue(draft(type: 'backup.created', entityId: 'b1'))).isSuccess, isTrue);
      expect((await recorder.recordOrQueue(draft(type: 'backup.created', entityId: 'b2'))).isSuccess, isTrue);
      expect(repo.outbox, hasLength(2));
      final firstTime = repo.outbox.first.draft.occurredAtUtc;

      repo.failAppend = false;
      expect((await recorder.flushOutbox()).valueOrNull, 2);
      expect(repo.outbox, isEmpty);
      final written = repo.events.where((e) => e.entityType == 'product').toList();
      expect(written.map((e) => e.entityId), ['b1', 'b2']);
      expect(written.first.occurredAtUtc, firstTime);
    });

    test('a later record flushes the outbox first', () async {
      final recorder = recorderFor(repo);
      repo.failAppend = true;
      await recorder.recordOrQueue(draft(entityId: 'old'));
      repo.failAppend = false;
      await recorder.recordOrQueue(draft(entityId: 'new'));
      expect(repo.outbox, isEmpty);
      expect(
        repo.events.where((e) => e.entityType == 'product').map((e) => e.entityId),
        ['old', 'new'],
      );
    });

    test('if even the outbox fails the caller is told', () async {
      repo
        ..failAppend = true
        ..failEnqueue = true;
      final r = await recorderFor(repo).recordOrQueue(draft());
      expect(r.failureOrNull, isA<AuditFailure>());
    });

    test('flushing stops at the first failure to keep order', () async {
      final recorder = recorderFor(repo);
      repo.failAppend = true;
      await recorder.recordOrQueue(draft(entityId: 'a'));
      await recorder.recordOrQueue(draft(entityId: 'b'));
      expect((await recorder.flushOutbox()).valueOrNull, 0);
      expect(repo.outbox, hasLength(2));
    });
  });

  group('verification', () {
    late MemoryAuditRepository repo;
    setUp(() async {
      repo = MemoryAuditRepository();
      final recorder = recorderFor(repo);
      for (var i = 0; i < 5; i++) {
        await recorder.record(draft(entityId: 'p$i', after: {'n': i}));
      }
    });

    VerifyAuditChain verify({int pageSize = 2}) =>
        VerifyAuditChain(repository: repo, hasher: hasher, pageSize: pageSize);

    AuditEvent edited(AuditEvent e, {Map<String, Object?>? newValues}) =>
        AuditEvent.stored(
          id: e.id,
          sequence: e.sequence,
          eventType: e.eventType,
          entityType: e.entityType,
          entityId: e.entityId,
          action: e.action,
          actor: e.actor,
          occurredAtUtc: e.occurredAtUtc,
          source: e.source,
          correlationId: e.correlationId,
          previousEventHash: e.previousEventHash,
          eventHash: e.eventHash,
          schemaVersion: e.schemaVersion,
          newValues: newValues,
        );

    test('an untouched chain is valid, across several pages', () async {
      final v = (await verify()()).valueOrNull!;
      expect(v.isValid, isTrue);
      expect(v.eventsChecked, 6); // genesis + 5
    });

    test('an empty chain is valid', () async {
      repo.events.clear();
      expect((await verify()()).valueOrNull!.isValid, isTrue);
    });

    test('an edited event is found at its position', () async {
      repo.events[3] = edited(repo.events[3], newValues: {'n': 999});
      final v = (await verify()()).valueOrNull!;
      expect(v.problem, AuditProblem.hashMismatch);
      expect(v.problemSequence, repo.events[3].sequence);
      expect(v.problemEventId, repo.events[3].id);
      expect(v.eventsChecked, 3);
    });

    test('a removed event breaks the link after it', () async {
      final gone = repo.events.removeAt(2);
      final v = (await verify()()).valueOrNull!;
      expect(v.problem, AuditProblem.brokenLink);
      expect(v.problemSequence, gone.sequence! + 1);
    });

    test('events presented in the wrong order are rejected', () async {
      final a = repo.events[2];
      repo.events[2] = repo.events[3];
      repo.events[3] = a;
      final v = (await verify()()).valueOrNull!;
      expect(v.isValid, isFalse);
    });

    test('an event from another chain is rejected', () async {
      final other = MemoryAuditRepository();
      await recorderFor(other).record(draft(entityId: 'x'));
      repo.events.insert(3, other.events.last);
      final v = (await verify()()).valueOrNull!;
      expect(v.isValid, isFalse);
    });

    test('deleting the last events is NOT caught by the chain alone', () async {
      repo.events.removeRange(4, repo.events.length);
      expect((await verify()()).valueOrNull!.isValid, isTrue);
    });

    test('...but a retained checkpoint catches it', () async {
      final checkpoint = (await CreateAuditCheckpoint(repository: repo, clock: StepClock())())
          .valueOrNull!;
      repo.events.removeRange(4, repo.events.length);
      final v = (await verify()(checkpoint: checkpoint)).valueOrNull!;
      expect(v.problem, AuditProblem.checkpointMissing);
      expect(v.checkpointChecked, isTrue);
    });

    test('a checkpoint on an intact chain passes', () async {
      final checkpoint = (await CreateAuditCheckpoint(repository: repo, clock: StepClock())())
          .valueOrNull!;
      final v = (await verify()(checkpoint: checkpoint)).valueOrNull!;
      expect(v.isValid, isTrue);
      expect(v.checkpointChecked, isTrue);
    });

    test('a chain rebuilt consistently after an edit still fails the checkpoint', () async {
      final checkpoint = (await CreateAuditCheckpoint(repository: repo, clock: StepClock())())
          .valueOrNull!;
      // An attacker with database access edits event 3 and re-hashes the
      // rest of the chain so the links are consistent again.
      final rebuilt = <AuditEvent>[];
      var previous = kAuditGenesisHash;
      for (final e in repo.events) {
        final fresh = AuditEvent.seal(
          id: e.id,
          eventType: e.eventType,
          entityType: e.entityType,
          entityId: e.entityId,
          action: e.action,
          actor: e.actor,
          occurredAtUtc: e.occurredAtUtc,
          source: e.source,
          correlationId: e.correlationId,
          previousEventHash: previous,
          hasher: hasher,
          newValues: e.sequence == 3 ? {'n': 999} : e.newValues,
        );
        previous = fresh.eventHash;
        rebuilt.add(
          AuditEvent.stored(
            id: fresh.id,
            sequence: e.sequence,
            eventType: fresh.eventType,
            entityType: fresh.entityType,
            entityId: fresh.entityId,
            action: fresh.action,
            actor: fresh.actor,
            occurredAtUtc: fresh.occurredAtUtc,
            source: fresh.source,
            correlationId: fresh.correlationId,
            previousEventHash: fresh.previousEventHash,
            eventHash: fresh.eventHash,
            schemaVersion: fresh.schemaVersion,
            newValues: fresh.newValues,
          ),
        );
      }
      repo.events
        ..clear()
        ..addAll(rebuilt);
      // The chain alone is consistent (documented limitation)...
      expect((await verify()()).valueOrNull!.isValid, isTrue);
      // ...but the checkpoint kept outside the database exposes it.
      final v = (await verify()(checkpoint: checkpoint)).valueOrNull!;
      expect(v.problem, AuditProblem.checkpointMissing);
    });
  });
}
