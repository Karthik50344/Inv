import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/di/register_backup.dart';
import 'package:inventrix/app/di/register_blocs.dart';
import 'package:inventrix/app/di/register_core.dart';
import 'package:inventrix/app/di/register_repositories.dart';
import 'package:inventrix/app/di/register_usecases.dart';
import 'package:inventrix/app/router/app_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/features/backup/domain/repositories/app_runtime.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';

/// Global service locator.
final GetIt getIt = GetIt.instance;

/// Registers all dependencies.
///
/// Pass [locator] and [database] in tests; [runtime] is the object that can
/// stop and restart the app (needed to restore a backup). Call [resetDependencies] before
/// calling this again (for example after restoring a backup).
Future<void> configureDependencies({
  GetIt? locator,
  AppDatabase? database,
  AppRuntime? runtime,
}) async {
  final target = locator ?? getIt;
  registerCore(target, database: database);
  registerRepositories(target);
  registerUseCases(target);
  registerBlocs(target);
  registerBackup(target, runtime: runtime);
  target.registerLazySingleton<GoRouter>(
    () => AppRouter.create(
      locator: target,
      // Settings are loaded before the router is first read, so a fresh
      // install opens the introduction and every later launch the dashboard.
      initialLocation: target<SettingsCubit>().state.preferences.introSeen
          ? RoutePaths.dashboard
          : RoutePaths.intro,
    ),
  );
}

/// Disposes registered singletons (closing the database) and clears the
/// locator.
Future<void> resetDependencies({GetIt? locator}) => (locator ?? getIt).reset();
