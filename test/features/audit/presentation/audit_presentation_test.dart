import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_query.dart';
import 'package:inventrix/features/audit/domain/entities/audit_verification.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_query_repository.dart';
import 'package:inventrix/features/audit/domain/usecases/verify_audit_chain.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_event_cubit.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_integrity_cubit.dart';
import 'package:inventrix/features/audit/presentation/bloc/audit_log_cubit.dart';
import 'package:inventrix/features/audit/presentation/support/audit_labels.dart';
import 'package:inventrix/features/audit/presentation/widgets/audit_event_tile.dart';
import 'package:inventrix/features/audit/presentation/widgets/value_diff.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../audit_test_support.dart';

class _Queries implements AuditQueryRepository {
  _Queries(this.events);
  final List<AuditEvent> events;
  final List<AuditEventFilter> searches = [];
  Failure? failure;
  Duration delay = Duration.zero;

  @override
  Future<Result<List<AuditEvent>>> search(AuditEventFilter f) async {
    searches.add(f);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (failure != null) {
      return Result.failure(failure!);
    }
    final matching = events.where((e) => f.search.isEmpty || e.entityId.contains(f.search)).toList();
    return Result.success(matching.skip(f.offset).take(f.limit).toList());
  }

  @override
  Future<Result<AuditStats>> stats({int recentLimit = 10}) async => throw UnimplementedError();

  @override
  Future<Result<AuditEvent?>> byId(String id) async {
    for (final e in events) {
      if (e.id == id) {
        return Result.success(e);
      }
    }
    return const Result.success(null);
  }

  @override
  Future<Result<List<AuditEvent>>> byCorrelation(String correlationId) async =>
      Result.success(events.where((e) => e.correlationId == correlationId).toList());

  @override
  Future<Result<List<String>>> eventTypes() async => const Result.success(['a.b']);

  @override
  Future<Result<List<String>>> entityTypes() async => const Result.success(['a']);
}

AuditEvent event(String id, {String entity = 'sales_invoice', String action = 'posted', Map<String, Object?>? before, Map<String, Object?>? after, Map<String, Object?>? meta, String correlation = 'c', String? hash}) {
  final sealed = AuditEvent.seal(
    id: id,
    eventType: '$entity.$action',
    entityType: entity,
    entityId: id,
    action: action,
    actor: AuditActor.localOperator('Ravi'),
    occurredAtUtc: DateTime.utc(2026, 6, 1, 10),
    source: 'app',
    correlationId: correlation,
    previousEventHash: kAuditGenesisHash,
    hasher: hasher,
    previousValues: before,
    newValues: after,
    metadata: meta,
  );
  return hash == null
      ? sealed
      : AuditEvent.stored(
          id: sealed.id,
          eventType: sealed.eventType,
          entityType: sealed.entityType,
          entityId: sealed.entityId,
          action: sealed.action,
          actor: sealed.actor,
          occurredAtUtc: sealed.occurredAtUtc,
          source: sealed.source,
          correlationId: sealed.correlationId,
          previousEventHash: sealed.previousEventHash,
          eventHash: hash,
          schemaVersion: sealed.schemaVersion,
        );
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('labels', () {
    test('events read as plain words', () {
      expect(AuditLabels.title(event('x', entity: 'sales_invoice', action: 'voided')), 'Sales invoice voided');
      expect(AuditLabels.title(event('x', entity: 'product_classification', action: 'primary_changed')), 'Product classification primary changed');
      expect(AuditLabels.entity('something_new'), 'something new');
      expect(AuditLabels.action('file_deleted'), 'File deleted');
    });

    test('field names and values are readable', () {
      expect(AuditLabels.field('sellingPriceMinor'), 'Selling price minor');
      expect(AuditLabels.field('tax_rate_id'), 'Tax rate id');
      expect(AuditLabels.value(null), 'Not set');
      expect(AuditLabels.value(true), 'Yes');
      expect(AuditLabels.value([1, 2]), '1, 2');
    });

    test('actors are never presented as verified people', () {
      expect(AuditLabels.actor(AuditActor.localOperator('Ravi')), contains('not verified'));
      expect(AuditLabels.actor(AuditActor.device), contains('no person'));
      expect(AuditLabels.actor(AuditActor.system), 'System');
    });

    test('the summary comes from the event details', () {
      expect(AuditLabels.summary(event('x', meta: {'summary': 'Posted INV-1'})), 'Posted INV-1');
      expect(AuditLabels.summary(event('x')), isNull);
    });
  });

  group('AuditLogCubit', () {
    List<AuditEvent> many(int n) => [for (var i = 0; i < n; i++) event('e$i')];

    test('loads the first page and the filter lists', () async {
      final cubit = AuditLogCubit(queries: _Queries(many(120)));
      await cubit.load();
      expect(cubit.state.status, ViewStatus.loaded);
      expect(cubit.state.events, hasLength(50));
      expect(cubit.state.hasMore, isTrue);
      expect(cubit.state.eventTypes, ['a.b']);
      await cubit.close();
    });

    test('loads further pages and stops at the end', () async {
      final cubit = AuditLogCubit(queries: _Queries(many(120)));
      await cubit.load();
      await cubit.loadMore();
      await cubit.loadMore();
      expect(cubit.state.events, hasLength(120));
      expect(cubit.state.hasMore, isFalse);
      await cubit.loadMore();
      expect(cubit.state.events, hasLength(120));
      await cubit.close();
    });

    test('an empty result is an empty state, a failure is a failure', () async {
      final queries = _Queries([]);
      final cubit = AuditLogCubit(queries: queries);
      await cubit.load();
      expect(cubit.state.status, ViewStatus.empty);
      queries.failure = const DatabaseFailure('locked');
      await cubit.apply(const AuditEventFilter());
      expect(cubit.state.status, ViewStatus.failure);
      expect(cubit.state.error, 'locked');
      await cubit.close();
    });

    test('applying a filter starts again from the first page', () async {
      final queries = _Queries(many(120));
      final cubit = AuditLogCubit(queries: queries);
      await cubit.load();
      await cubit.loadMore();
      await cubit.apply(const AuditEventFilter(search: 'e1'));
      expect(queries.searches.last.offset, 0);
      expect(cubit.state.events.every((e) => e.entityId.contains('e1')), isTrue);
      await cubit.close();
    });

    test('typing searches after a pause, not on every key', () async {
      final queries = _Queries(many(10));
      final cubit = AuditLogCubit(queries: queries, debounce: const Duration(milliseconds: 10));
      await cubit.load();
      final before = queries.searches.length;
      cubit
        ..search('e')
        ..search('e1')
        ..search('e12');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(queries.searches.length, before + 1);
      expect(queries.searches.last.search, 'e12');
      await cubit.close();
    });

    test('a slow older response never overwrites a newer one', () async {
      final queries = _Queries(many(10))..delay = const Duration(milliseconds: 30);
      final cubit = AuditLogCubit(queries: queries);
      final first = cubit.apply(const AuditEventFilter(search: 'e1'));
      queries.delay = Duration.zero;
      await cubit.apply(const AuditEventFilter(search: 'e2'));
      await first;
      expect(cubit.state.filter.search, 'e2');
      await cubit.close();
    });

    test('the number of active filters ignores the search text', () async {
      final cubit = AuditLogCubit(queries: _Queries(many(3)));
      await cubit.apply(AuditEventFilter(search: 'x', eventType: 'a.b', from: DateTime.utc(2026), actor: 'Ravi'));
      expect(cubit.state.activeFilterCount, 3);
      await cubit.clearFilters();
      expect(cubit.state.activeFilterCount, 0);
      expect(cubit.state.filter.search, 'x');
      await cubit.close();
    });
  });

  group('AuditEventCubit', () {
    test('an untouched event is valid and related events are listed', () async {
      final a = event('a', correlation: 'op');
      final b = event('b', correlation: 'op');
      final cubit = AuditEventCubit(queries: _Queries([a, b]), hasher: hasher);
      await cubit.load('a');
      expect(cubit.state.status, ViewStatus.loaded);
      expect(cubit.state.hashValid, isTrue);
      expect(cubit.state.related.map((e) => e.id), ['b']);
    });

    test('an event whose fingerprint does not match is flagged', () async {
      final bad = event('a', hash: 'f' * 64);
      final cubit = AuditEventCubit(queries: _Queries([bad]), hasher: hasher);
      await cubit.load('a');
      expect(cubit.state.hashValid, isFalse);
    });

    test('a missing event is reported', () async {
      final cubit = AuditEventCubit(queries: _Queries([]), hasher: hasher);
      await cubit.load('nope');
      expect(cubit.state.status, ViewStatus.failure);
    });
  });

  group('AuditIntegrityCubit', () {
    late MemoryAuditRepository repo;
    late AuditIntegrityCubit cubit;

    setUp(() async {
      repo = MemoryAuditRepository();
      final recorder = recorderFor(repo);
      for (var i = 0; i < 3; i++) {
        await recorder.record(draft(entityId: 'p$i'));
      }
      cubit = AuditIntegrityCubit(
        verify: VerifyAuditChain(repository: repo, hasher: hasher),
        createCheckpoint: CreateAuditCheckpoint(repository: repo, clock: StepClock()),
        clock: StepClock(),
      );
    });

    test('an intact log verifies', () async {
      await cubit.verify();
      expect(cubit.state.result!.isValid, isTrue);
      expect(cubit.state.result!.eventsChecked, 4);
      expect(cubit.state.running, isFalse);
    });

    test('a changed log is reported with its position', () async {
      repo.events.removeAt(0);
      await cubit.verify();
      expect(cubit.state.result!.isValid, isFalse);
      expect(cubit.state.result!.problem, AuditProblem.brokenLink);
    });

    test('a checkpoint can be created and compared', () async {
      await cubit.makeCheckpoint();
      final cp = cubit.state.checkpoint!;
      await cubit.verifyAgainst('${cp.sequence}', cp.eventHash);
      expect(cubit.state.result!.isValid, isTrue);
      expect(cubit.state.comparedWithCheckpoint, isTrue);
      expect(cubit.state.checkpoint, cp);
    });

    test('a checkpoint that is not in the log is caught', () async {
      await cubit.verifyAgainst('3', 'a' * 64);
      expect(cubit.state.result!.problem, AuditProblem.checkpointMissing);
    });

    test('a badly typed checkpoint is refused before checking anything', () async {
      await cubit.verifyAgainst('x', 'short');
      expect(cubit.state.checkpointError, isNotNull);
      expect(cubit.state.result, isNull);
    });

    test('the code may be typed in capitals', () async {
      await cubit.makeCheckpoint();
      final cp = cubit.state.checkpoint!;
      await cubit.verifyAgainst(' ${cp.sequence} ', cp.eventHash.toUpperCase());
      expect(cubit.state.result!.isValid, isTrue);
    });
  });

  group('widgets', () {
    Future<void> pump(WidgetTester tester, Widget child, {ThemeData? theme}) async {
      tester.view
        ..physicalSize = const Size(420, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: theme ?? AppTheme.light(), home: Scaffold(body: SingleChildScrollView(child: child))));
    }

    for (final theme in {'light': AppTheme.light(), 'dark': AppTheme.dark()}.entries) {
      testWidgets('before and after are both shown, in ${theme.key}', (tester) async {
        await pump(
          tester,
          const ValueDiff(previous: {'sellingPriceMinor': 100, 'name': 'Hammer'}, next: {'sellingPriceMinor': 120, 'name': 'Hammer'}),
          theme: theme.value,
        );
        expect(find.text('Selling price minor'), findsOneWidget);
        expect(find.text('Before'), findsNWidgets(2)); // changed and unchanged row
        expect(find.text('100'), findsOneWidget);
        expect(find.text('120'), findsOneWidget);
        expect(find.text('Unchanged'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a created record shows only After', (tester) async {
      await pump(tester, const ValueDiff(next: {'sku': 'A-1'}));
      expect(find.text('Before'), findsNothing);
      expect(find.text('After'), findsOneWidget);
    });

    testWidgets('no values gives a plain sentence', (tester) async {
      await pump(tester, const ValueDiff());
      expect(find.textContaining('No values were recorded'), findsOneWidget);
    });

    testWidgets('the event tile shows the title, summary and person', (tester) async {
      var tapped = false;
      await pump(
        tester,
        AuditEventTile(
          event: event('x', action: 'voided', meta: {'summary': 'Voided INV-1: wrong customer'}),
          onTap: () => tapped = true,
        ),
      );
      expect(find.text('Sales invoice voided'), findsOneWidget);
      expect(find.text('Voided INV-1: wrong customer'), findsOneWidget);
      expect(find.textContaining('Ravi'), findsOneWidget);
      await tester.tap(find.byType(AuditEventTile));
      expect(tapped, isTrue);
    });
  });
}
