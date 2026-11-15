import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';

import 'database_test_helpers.dart';

void main() {
  late AppDatabase db;
  late DriftTransactionRunner runner;

  Future<int> unitCount() async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM units')
        .getSingle();
    return row.read<int>('c');
  }

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.initialize();
    runner = DriftTransactionRunner(db);
  });

  tearDown(() async => db.close());

  test('commits all writes when the action succeeds', () async {
    await runner.run(() async {
      await insertUnit(db, 'u1', symbol: 'a');
      await insertUnit(db, 'u2', symbol: 'b');
    });
    expect(await unitCount(), 2);
  });

  test('rolls back every write when the action throws', () async {
    await expectLater(
      runner.run(() async {
        await insertUnit(db, 'u1', symbol: 'a');
        throw StateError('boom');
      }),
      throwsA(isA<StateError>()),
    );
    expect(await unitCount(), 0);
  });

  test('rolls back when a later write violates a constraint', () async {
    final failure = await failureOf(
      () => runner.run(() async {
        await insertUnit(db, 'u1', symbol: 'a');
        await insertUnit(db, 'u2', symbol: 'a');
      }),
    );
    expect(failure, isA<DuplicateEntryFailure>());
    expect(await unitCount(), 0);
  });

  test('FailureException keeps its failure type and rolls back', () async {
    const stock = InsufficientStockFailure(
      'not enough',
      productId: 'p1',
      requestedMilli: 2000,
      availableMilli: 1000,
    );
    final result = await guardDatabase<void>(
      () => runner.run(() async {
        await insertUnit(db, 'u1', symbol: 'a');
        throw const FailureException(stock);
      }),
    );
    expect(result.failureOrNull, isA<InsufficientStockFailure>());
    expect(await unitCount(), 0);
  });

  test('runResult commits and returns the value', () async {
    final result = await runner.runResult(() async {
      await insertUnit(db, 'u1', symbol: 'a');
      return 7;
    });
    expect(result.valueOrNull, 7);
    expect(await unitCount(), 1);
  });

  test('runResult rolls back and keeps the typed failure', () async {
    const stock = InsufficientStockFailure(
      'not enough',
      productId: 'p1',
      requestedMilli: 2000,
      availableMilli: 1000,
    );
    final result = await runner.runResult<void>(() async {
      await insertUnit(db, 'u1', symbol: 'a');
      throw const FailureException(stock);
    });
    expect(result.failureOrNull, isA<InsufficientStockFailure>());
    expect(await unitCount(), 0);
  });

  test('runResult maps constraint violations and rolls back', () async {
    final result = await runner.runResult<void>(() async {
      await insertUnit(db, 'u1', symbol: 'a');
      await insertUnit(db, 'u2', symbol: 'a');
    });
    expect(result.failureOrNull, isA<DuplicateEntryFailure>());
    expect(await unitCount(), 0);
  });

  test(
    'a failed Result unwrapped inside the action aborts the transaction',
    () async {
      final result = await runner.runResult<void>(() async {
        await insertUnit(db, 'u1', symbol: 'a');
        const Result<void>.failure(DatabaseFailure('step failed')).getOrThrow();
      });
      expect(result.failureOrNull, isA<DatabaseFailure>());
      expect(await unitCount(), 0);
    },
  );

  test('guardDatabase returns success values', () async {
    final result = await guardDatabase(() async => 42);
    expect(result.valueOrNull, 42);
  });
}
