import 'package:get_it/get_it.dart';
import 'package:inventrix/app/runtime/unavailable_app_runtime.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_session.dart';
import 'package:inventrix/core/security/secret_store.dart';
import 'package:inventrix/core/security/secure_storage_secret_store.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/features/backup/data/repositories/drift_backup_history_repository.dart';
import 'package:inventrix/features/backup/data/services/app_storage_locations.dart';
import 'package:inventrix/features/backup/data/services/drift_database_snapshotter.dart';
import 'package:inventrix/features/backup/data/services/encrypted_backup_packager.dart';
import 'package:inventrix/features/backup/data/services/session_backup_key_provider.dart';
import 'package:inventrix/features/backup/data/services/sqlcipher_key_aligner.dart';
import 'package:inventrix/features/backup/data/services/file_restore_journal_store.dart';
import 'package:inventrix/features/backup/data/services/file_restore_swapper.dart';
import 'package:inventrix/features/backup/data/services/platform_backup_exporter.dart';
import 'package:inventrix/features/backup/data/services/sqlite_database_inspector.dart';
import 'package:inventrix/features/backup/data/services/zip_backup_packager.dart';
import 'package:inventrix/features/backup/domain/repositories/app_runtime.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_exporter.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_history_repository.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_key_provider.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_locations.dart';
import 'package:inventrix/features/backup/domain/repositories/database_key_aligner.dart';
import 'package:inventrix/features/backup/domain/repositories/backup_packager.dart';
import 'package:inventrix/features/backup/domain/repositories/database_inspector.dart';
import 'package:inventrix/features/backup/domain/repositories/database_snapshotter.dart';
import 'package:inventrix/features/backup/domain/repositories/restore_journal_store.dart';
import 'package:inventrix/features/backup/domain/repositories/restore_swapper.dart';
import 'package:inventrix/features/backup/domain/usecases/create_backup.dart';
import 'package:inventrix/features/backup/domain/usecases/manage_backups.dart';
import 'package:inventrix/features/backup/domain/usecases/prepare_restore.dart';
import 'package:inventrix/features/backup/domain/usecases/recover_restore.dart';
import 'package:inventrix/features/backup/domain/usecases/restore_backup.dart';
import 'package:inventrix/features/backup/presentation/bloc/backup_bloc.dart';
import 'package:path_provider/path_provider.dart';

/// Registers the backup feature (repositories, services, use cases, BLoC).
///
/// [runtime] is the object that can stop and restart the app; without one a
/// restore is refused before any file is touched.
void registerBackup(
  GetIt locator, {
  AppRuntime? runtime,
  DatabaseSession? session,
}) {
  locator
    ..registerLazySingleton<BackupKeyProvider>(
      () => SessionBackupKeyProvider(
        keys: SecretKeyManager(SecureStorageSecretStore()),
        session: session,
      ),
    )
    ..registerLazySingleton<DatabaseKeyAligner>(SqlcipherKeyAligner.new)
    ..registerLazySingleton<AppRuntime>(
      () => runtime ?? const UnavailableAppRuntime(),
    )
    ..registerLazySingleton<BackupHistoryRepository>(
      () => DriftBackupHistoryRepository(locator<AppDatabase>()),
    )
    ..registerLazySingleton<BackupLocations>(
      () => AppStorageLocations(
        documents: getApplicationDocumentsDirectory,
        temporary: getTemporaryDirectory,
        databasePath: () async {
          // Ask SQLite itself where the open database lives, so the swap
          // always targets the file that is really in use.
          final rows = await locator<AppDatabase>()
              .customSelect('PRAGMA database_list')
              .get();
          return rows
              .firstWhere((row) => row.read<String>('name') == 'main')
              .read<String>('file');
        },
      ),
    )
    ..registerLazySingleton<DatabaseSnapshotter>(
      () => DriftDatabaseSnapshotter(locator<AppDatabase>()),
    )
    ..registerLazySingleton<DatabaseInspector>(SqliteDatabaseInspector.new)
    ..registerLazySingleton<BackupPackager>(
      () => EncryptedBackupPackager(
        inner: ZipBackupPackager(),
        keys: locator<BackupKeyProvider>(),
        locations: locator<BackupLocations>(),
      ),
    )
    ..registerLazySingleton<BackupExporter>(PlatformBackupExporter.new)
    ..registerLazySingleton<RestoreSwapper>(FileRestoreSwapper.new)
    ..registerLazySingleton<RestoreJournalStore>(
      () => FileRestoreJournalStore(getApplicationDocumentsDirectory),
    )
    ..registerFactory<CreateBackup>(
      () => CreateBackup(
        snapshotter: locator<DatabaseSnapshotter>(),
        inspector: locator<DatabaseInspector>(),
        packager: locator<BackupPackager>(),
        locations: locator<BackupLocations>(),
        history: locator<BackupHistoryRepository>(),
        keys: locator<BackupKeyProvider>(),
        ids: locator<IdGenerator>(),
        clock: locator<Clock>(),
        appVersion: AppConstants.appVersion,
      ),
    )
    ..registerFactory<ListBackups>(
      () => ListBackups(
        history: locator<BackupHistoryRepository>(),
        locations: locator<BackupLocations>(),
      ),
    )
    ..registerFactory<DeleteStoredBackup>(
      () => DeleteStoredBackup(
        history: locator<BackupHistoryRepository>(),
        locations: locator<BackupLocations>(),
      ),
    )
    ..registerFactory<ExportBackup>(
      () => ExportBackup(
        history: locator<BackupHistoryRepository>(),
        locations: locator<BackupLocations>(),
        packager: locator<BackupPackager>(),
        exporter: locator<BackupExporter>(),
        clock: locator<Clock>(),
      ),
    )
    ..registerFactory<PrepareRestore>(
      () => PrepareRestore(
        packager: locator<BackupPackager>(),
        inspector: locator<DatabaseInspector>(),
        locations: locator<BackupLocations>(),
      ),
    )
    ..registerFactory<DiscardStagedBackup>(
      () => DiscardStagedBackup(locations: locator<BackupLocations>()),
    )
    ..registerFactory<RestoreBackup>(
      () => RestoreBackup(
        inspector: locator<DatabaseInspector>(),
        locations: locator<BackupLocations>(),
        createBackup: locator<CreateBackup>(),
        keys: locator<BackupKeyProvider>(),
        aligner: locator<DatabaseKeyAligner>(),
        swapper: locator<RestoreSwapper>(),
        journal: locator<RestoreJournalStore>(),
        runtime: locator<AppRuntime>(),
        ids: locator<IdGenerator>(),
        clock: locator<Clock>(),
      ),
    )
    ..registerFactory<ReconcileRestoreJournal>(
      () => ReconcileRestoreJournal(
        journal: locator<RestoreJournalStore>(),
        history: locator<BackupHistoryRepository>(),
        swapper: locator<RestoreSwapper>(),
        appVersion: AppConstants.appVersion,
      ),
    )
    ..registerFactory<BackupBloc>(
      () => BackupBloc(
        listBackups: locator<ListBackups>(),
        createBackup: locator<CreateBackup>(),
        exportBackup: locator<ExportBackup>(),
        deleteBackup: locator<DeleteStoredBackup>(),
        prepareRestore: locator<PrepareRestore>(),
        discardStaged: locator<DiscardStagedBackup>(),
        restoreBackup: locator<RestoreBackup>(),
        locations: locator<BackupLocations>(),
      ),
    );
}
