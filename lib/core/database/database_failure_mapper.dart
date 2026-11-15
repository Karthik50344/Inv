import 'package:inventrix/core/errors/domain_exception.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:logging/logging.dart';
import 'package:sqlite3/sqlite3.dart';

final Logger _log = Logger('database');

const int _sqliteConstraintCheck = 275;
const int _sqliteConstraintForeignKey = 787;
const int _sqliteConstraintNotNull = 1299;
const int _sqliteConstraintPrimaryKey = 1555;
const int _sqliteConstraintTrigger = 1811;
const int _sqliteConstraintUnique = 2067;

/// Translates an exception thrown by the persistence layer into a
/// [Failure] with a user-safe message. Raw SQL is kept only in `cause`.
Failure mapDatabaseError(Object error, StackTrace stackTrace) {
  if (error is FailureException) {
    return error.failure;
  }
  if (error is DomainException) {
    return ValidationFailure(
      error.message,
      cause: error,
      stackTrace: stackTrace,
    );
  }
  if (error is SqliteException) {
    return _fromCode(
          error.extendedResultCode,
          error.message,
          error,
          stackTrace,
        ) ??
        DatabaseFailure(
          'The database operation failed.',
          cause: error,
          stackTrace: stackTrace,
        );
  }
  return _fromText(error.toString(), error, stackTrace) ??
      UnexpectedFailure(
        'Unexpected error.',
        cause: error,
        stackTrace: stackTrace,
      );
}

/// Runs [action] and converts any thrown error into a failed [Result].
Future<Result<T>> guardDatabase<T>(Future<T> Function() action) async {
  try {
    return Result.success(await action());
  } on Object catch (error, stackTrace) {
    final failure = mapDatabaseError(error, stackTrace);
    _log.warning('Operation failed: ${failure.runtimeType}', error, stackTrace);
    return Result.failure(failure);
  }
}

Failure? _fromCode(int code, String text, Object error, StackTrace stackTrace) {
  switch (code) {
    case _sqliteConstraintUnique:
    case _sqliteConstraintPrimaryKey:
      return DuplicateEntryFailure(
        'A record with the same unique value already exists.',
        cause: error,
        stackTrace: stackTrace,
      );
    case _sqliteConstraintForeignKey:
      return ValidationFailure(
        'This record is linked to other data and cannot be changed this way.',
        cause: error,
        stackTrace: stackTrace,
      );
    case _sqliteConstraintCheck:
    case _sqliteConstraintNotNull:
      return ValidationFailure(
        'A value is missing or not allowed.',
        cause: error,
        stackTrace: stackTrace,
      );
    case _sqliteConstraintTrigger:
      return DatabaseFailure(
        'This operation is not permitted on protected records.',
        cause: error,
        stackTrace: stackTrace,
      );
  }
  return _fromText(text, error, stackTrace);
}

Failure? _fromText(String text, Object error, StackTrace stackTrace) {
  if (text.contains('UNIQUE constraint failed')) {
    return DuplicateEntryFailure(
      'A record with the same unique value already exists.',
      cause: error,
      stackTrace: stackTrace,
    );
  }
  if (text.contains('FOREIGN KEY constraint failed')) {
    return ValidationFailure(
      'This record is linked to other data and cannot be changed this way.',
      cause: error,
      stackTrace: stackTrace,
    );
  }
  if (text.contains('CHECK constraint failed') ||
      text.contains('NOT NULL constraint failed')) {
    return ValidationFailure(
      'A value is missing or not allowed.',
      cause: error,
      stackTrace: stackTrace,
    );
  }
  if (text.contains('append-only')) {
    return DatabaseFailure(
      'This operation is not permitted on protected records.',
      cause: error,
      stackTrace: stackTrace,
    );
  }
  return null;
}
