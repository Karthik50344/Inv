import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/di/register_blocs.dart';
import 'package:inventrix/app/di/register_core.dart';
import 'package:inventrix/app/di/register_repositories.dart';
import 'package:inventrix/app/di/register_usecases.dart';
import 'package:inventrix/app/router/app_router.dart';
import 'package:inventrix/core/database/app_database.dart';

/// Global service locator.
final GetIt getIt = GetIt.instance;

/// Registers all dependencies.
///
/// Pass [locator] and [database] in tests. Call [resetDependencies] before
/// calling this again (for example after restoring a backup).
Future<void> configureDependencies({
  GetIt? locator,
  AppDatabase? database,
}) async {
  final target = locator ?? getIt;
  registerCore(target, database: database);
  registerRepositories(target);
  registerUseCases(target);
  registerBlocs(target);
  target.registerLazySingleton<GoRouter>(
    () => AppRouter.create(locator: target),
  );
}

/// Disposes registered singletons (closing the database) and clears the
/// locator.
Future<void> resetDependencies({GetIt? locator}) => (locator ?? getIt).reset();
