import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/audit/data/repositories/audit_event_log_repository.dart';
import 'package:inventrix/features/audit/data/repositories/drift_audit_event_repository.dart';
import 'package:inventrix/features/audit/data/services/settings_audit_actor_provider.dart';
import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';
import 'package:inventrix/features/audit/domain/services/audit_recorder.dart';
import 'package:inventrix/features/audit/domain/usecases/save_audit_operator_name.dart';
import 'package:inventrix/shared/data/drift_audit_log_repository.dart';

import '../features/audit/audit_test_support.dart';

/// Real schema. Written without a Flutter SDK: not yet executed.
void main() {
  late AppDatabase db;
  late SaveAuditOperatorName save;
  late SettingsAuditOperatorRepository repo;
  late AuditRecorder recorder;

  Future<List<Map<String, Object?>>> events(String where) async => [
    for (final r in await db.customSelect('SELECT * FROM audit_events WHERE $where ORDER BY seq').get()) r.data,
  ];

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    repo = SettingsAuditOperatorRepository(db);
    final eventsRepo = DriftAuditEventRepository(db);
    recorder = AuditRecorder(
      repository: eventsRepo,
      actors: SettingsAuditActorProvider(db),
      hasher: hasher,
      clock: StepClock(DateTime.utc(2026, 6, 1)),
      ids: CountingIds(),
    );
    save = SaveAuditOperatorName(
      repository: repo,
      transactions: DriftTransactionRunner(db, ids: CountingIds()),
      audit: AuditEventLogRepository(recorder: recorder, events: eventsRepo, legacy: DriftAuditLogRepository(db)),
      clock: StepClock(DateTime.utc(2026, 6, 1)),
      ids: CountingIds(),
    );
  });

  tearDown(() => db.close());

  test('no name is set at first', () async {
    expect((await repo.name()).valueOrNull, isNull);
  });

  test('the name is saved, trimmed and tidied, and recorded with old and new value', () async {
    expect((await save('  Ravi   Kumar ')).isSuccess, isTrue);
    expect((await repo.name()).valueOrNull, 'Ravi Kumar');
    final e = (await events("action = 'operator_changed'")).single;
    expect(e['previous_values'], '{"name":null}');
    expect(e['new_values'], '{"name":"Ravi Kumar"}');
  });

  test('later events carry the new name, as an unverified local operator', () async {
    await save('Mala');
    await recorder.record(draft());
    final last = (await events('1 = 1')).last;
    expect(last['actor_type'], AuditActorType.localOperator.code);
    expect(last['actor_display_name'], 'Mala');
  });

  test('saving the same name again records nothing', () async {
    await save('Mala');
    final count = (await events("action = 'operator_changed'")).length;
    await save(' Mala ');
    expect((await events("action = 'operator_changed'")).length, count);
  });

  test('an empty name clears it and events name the device again', () async {
    await save('Mala');
    await save('');
    expect((await repo.name()).valueOrNull, isNull);
    await recorder.record(draft());
    expect((await events('1 = 1')).last['actor_type'], AuditActorType.device.code);
  });

  test('a name that is too long is refused', () async {
    final r = await save('x' * 41);
    expect(r.failureOrNull, isA<ValidationFailure>());
    expect((await repo.name()).valueOrNull, isNull);
  });
}
