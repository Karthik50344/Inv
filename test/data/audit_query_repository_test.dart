import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/features/audit/data/repositories/drift_audit_event_repository.dart';
import 'package:inventrix/features/audit/data/repositories/drift_audit_query_repository.dart';
import 'package:inventrix/features/audit/data/services/settings_audit_actor_provider.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event_draft.dart';
import 'package:inventrix/features/audit/domain/entities/audit_query.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';

import '../features/audit/audit_test_support.dart';

/// Real schema (in-memory SQLite). Written without a Flutter SDK: not yet
/// executed.
void main() {
  late AppDatabase db;
  late DriftAuditQueryRepository query;
  late AuditRecorder recorder;

  Future<void> add(
    String type,
    String entityId, {
    String? reason,
    DateTime? at,
    Map<String, Object?>? metadata,
    Map<String, Object?>? after,
    AuditActor? actor,
  }) async {
    final r = await recorder.record(
      AuditEventDraft(
        eventType: type,
        entityType: type.split('.').first,
        entityId: entityId,
        action: type.split('.').last,
        reason: reason,
        metadata: metadata,
        newValues: after,
        occurredAtUtc: at,
        actor: actor,
      ),
    );
    expect(r.isSuccess, isTrue, reason: r.failureOrNull?.toString());
  }

  Future<List<String>> ids(AuditEventFilter f) async =>
      (await query.search(f)).valueOrNull!.map((e) => e.entityId).toList();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    query = DriftAuditQueryRepository(db);
    recorder = AuditRecorder(
      repository: DriftAuditEventRepository(db),
      actors: SettingsAuditActorProvider(db),
      hasher: hasher,
      clock: StepClock(DateTime.utc(2026, 6, 1)),
      ids: CountingIds(),
    );
    await add('sales_invoice.posted', 's1', at: DateTime.utc(2026, 6, 1, 10), metadata: {'summary': 'Posted INV-0001'});
    await add('sales_invoice.voided', 's1', reason: 'Wrong customer', at: DateTime.utc(2026, 6, 2, 10), metadata: {'summary': 'Voided INV-0001: Wrong customer'});
    await add('payment.reversed', 'pay1', reason: 'Bounced cheque', at: DateTime.utc(2026, 6, 3, 10), actor: AuditActor.localOperator('Mala'));
    await add('stock.adjusted', 'p1', at: DateTime.utc(2026, 6, 4, 10), after: {'quantity': '5'});
    await add('tax_rate.updated', 't1', at: DateTime.utc(2026, 6, 5, 10));
    await add('product.updated', 'p1', at: DateTime.utc(2026, 6, 6, 10), metadata: {'taxTreatmentChanged': true});
  });

  tearDown(() => db.close());

  test('newest first, including the genesis event at the end', () async {
    final all = (await query.search(const AuditEventFilter(limit: 100))).valueOrNull!;
    expect(all.first.eventType, 'product.updated');
    expect(all.last.eventType, 'audit.chain_started');
    expect(all, hasLength(7));
  });

  test('paging', () async {
    const first = AuditEventFilter(limit: 3);
    expect(await ids(first), ['p1', 't1', 'p1']);
    expect((await ids(first.nextPage())).length, 3);
    expect((await ids(first.nextPage().nextPage())).length, 1);
  });

  test('filter by event type and by record type', () async {
    expect(await ids(const AuditEventFilter(eventType: 'sales_invoice.voided')), ['s1']);
    expect(await ids(const AuditEventFilter(entityType: 'sales_invoice')), ['s1', 's1']);
  });

  test('filter by date range, inclusive of both days', () async {
    final f = AuditEventFilter(from: DateTime.utc(2026, 6, 2), to: DateTime.utc(2026, 6, 3));
    expect(await ids(f), ['pay1', 's1']);
  });

  test('find by document number in the summary', () async {
    expect(await ids(const AuditEventFilter(reference: 'inv-0001')), ['s1', 's1']);
    expect(await ids(const AuditEventFilter(reference: 'INV-9999')), isEmpty);
  });

  test('free text searches reason, actor and values', () async {
    expect(await ids(const AuditEventFilter(search: 'bounced')), ['pay1']);
    expect(await ids(const AuditEventFilter(search: 'mala')), ['pay1']);
    expect(await ids(const AuditEventFilter(search: '"quantity"')), ['p1']);
  });

  test('filter by actor', () async {
    expect(await ids(const AuditEventFilter(actor: 'Mala')), ['pay1']);
  });

  test('criteria combine', () async {
    final f = AuditEventFilter(entityType: 'sales_invoice', from: DateTime.utc(2026, 6, 2));
    expect(await ids(f), ['s1']);
  });

  test('wildcard characters in the search are taken literally', () async {
    expect(await ids(const AuditEventFilter(search: '%')), isEmpty);
    expect(await ids(const AuditEventFilter(search: '_')), isEmpty);
  });

  test('dashboard numbers come from the real events', () async {
    final s = (await query.stats()).valueOrNull!;
    expect(s.totalEvents, 7);
    expect(s.cancelledDocuments, 1);
    expect(s.reversedPayments, 1);
    expect(s.stockAdjustments, 1);
    expect(s.taxConfigurationChanges, 2); // tax_rate.updated + product tax change
    expect(s.dataExports, 0);
    expect(s.byType['sales_invoice.posted'], 1);
    expect(s.recent.first.eventType, 'product.updated');
    expect(s.recent.length, 7);
    expect((await query.stats(recentLimit: 2)).valueOrNull!.recent, hasLength(2));
  });

  test('details, related events and filter lists', () async {
    final events = (await query.search(const AuditEventFilter(entityType: 'stock'))).valueOrNull!;
    final e = events.single;
    expect((await query.byId(e.id)).valueOrNull!.newValues, {'quantity': '5'});
    expect((await query.byId('nope')).valueOrNull, isNull);
    expect((await query.byCorrelation(e.correlationId)).valueOrNull, contains(e));
    expect((await query.eventTypes()).valueOrNull, contains('payment.reversed'));
    expect((await query.entityTypes()).valueOrNull, containsAll(['payment', 'stock', 'tax_rate']));
  });
}
