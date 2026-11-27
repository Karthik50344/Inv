import 'package:get_it/get_it.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_provider.dart';
import 'package:inventrix/core/database/database_session.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/services/uuid_id_generator.dart';

/// Registers infrastructure shared by every feature.
///
/// Pass [database] in tests to use an in-memory database; in the app pass
/// the unlocked [session] (the database is never opened without a key). The database is
/// closed when the locator is reset.
void registerCore(
  GetIt locator, {
  AppDatabase? database,
  DatabaseSession? session,
}) {
  locator
    ..registerLazySingleton<AppDatabase>(
      () =>
          database ??
          AppDatabase(
            openAppDatabaseConnection(
              session ??
                  (throw StateError(
                    'The encrypted database session is missing; the app must '
                    'unlock the database before registering dependencies.',
                  )),
            ),
          ),
      dispose: (db) => db.close(),
    )
    ..registerLazySingleton<TransactionRunner>(
      () => DriftTransactionRunner(
        locator<AppDatabase>(),
        ids: locator<IdGenerator>(),
      ),
    )
    ..registerLazySingleton<Clock>(() => const SystemClock())
    ..registerLazySingleton<IdGenerator>(UuidIdGenerator.new);
}
