import 'package:get_it/get_it.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_provider.dart';
import 'package:inventrix/core/database/drift_transaction_runner.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/services/transaction_runner.dart';
import 'package:inventrix/core/services/uuid_id_generator.dart';

/// Registers infrastructure shared by every feature.
///
/// Pass [database] in tests to use an in-memory database. The database is
/// closed when the locator is reset.
void registerCore(GetIt locator, {AppDatabase? database}) {
  locator
    ..registerLazySingleton<AppDatabase>(
      () => database ?? AppDatabase(openAppDatabaseConnection()),
      dispose: (db) => db.close(),
    )
    ..registerLazySingleton<TransactionRunner>(
      () => DriftTransactionRunner(locator<AppDatabase>()),
    )
    ..registerLazySingleton<Clock>(() => const SystemClock())
    ..registerLazySingleton<IdGenerator>(UuidIdGenerator.new);
}
