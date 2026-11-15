import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';

void main() {
  group('Result', () {
    test('success exposes its value', () {
      const result = Result<int>.success(4);
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 4);
      expect(result.failureOrNull, isNull);
    });

    test('failure exposes its failure', () {
      const failure = NotFoundFailure('missing');
      const result = Result<int>.failure(failure);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('when folds both branches', () {
      const ok = Result<int>.success(2);
      const bad = Result<int>.failure(ValidationFailure('no'));
      expect(ok.when(success: (v) => 'v$v', failure: (f) => 'f'), 'v2');
      expect(bad.when(success: (v) => 'v', failure: (f) => f.message), 'no');
    });

    test('map transforms successes and keeps failures', () {
      const ok = Result<int>.success(2);
      const bad = Result<int>.failure(ValidationFailure('no'));
      expect(ok.map((v) => v * 3).valueOrNull, 6);
      expect(bad.map((v) => v * 3).failureOrNull?.message, 'no');
    });

    test('flatMap chains and short-circuits', () {
      const ok = Result<int>.success(2);
      const bad = Result<int>.failure(ValidationFailure('no'));
      expect(ok.flatMap((v) => Result<int>.success(v + 1)).valueOrNull, 3);
      expect(
        ok.flatMap((v) => const Result<int>.failure(NotFoundFailure('x'))),
        isA<Err<int>>(),
      );
      expect(bad.flatMap((v) => Result<int>.success(v + 1)), isA<Err<int>>());
    });

    test('Success values compare by value', () {
      expect(const Success<int>(1), const Success<int>(1));
      expect(const Success<int>(1) == const Success<int>(2), isFalse);
    });
  });

  group('Failure', () {
    test('unexpected and database failures hide technical details', () {
      const unexpected = UnexpectedFailure('boom', cause: 'secret');
      const database = DatabaseFailure('SELECT * FROM x failed');
      expect(unexpected.userMessage.contains('boom'), isFalse);
      expect(unexpected.userMessage.contains('secret'), isFalse);
      expect(database.message.contains('SELECT'), isTrue);
    });

    test('InsufficientStockFailure carries quantities', () {
      const failure = InsufficientStockFailure(
        'not enough',
        productId: 'p1',
        requestedMilli: 5000,
        availableMilli: 2000,
      );
      expect(failure.productId, 'p1');
      expect(failure.requestedMilli, 5000);
      expect(failure.availableMilli, 2000);
    });

    test('FailureException wraps a failure', () {
      const failure = DuplicateEntryFailure('dup');
      expect(const FailureException(failure).failure, failure);
    });
  });
}
