import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/di/injection.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_session.dart';
import 'package:inventrix/core/database/encrypted_database_opener.dart';
import 'package:inventrix/core/database/sqlcipher_gateway_impl.dart';
import 'package:inventrix/core/security/secret_store.dart';
import 'package:inventrix/core/security/secure_storage_secret_store.dart';
import 'package:inventrix/features/backup/data/services/file_restore_journal_store.dart';
import 'package:inventrix/features/backup/data/services/file_restore_swapper.dart';
import 'package:inventrix/features/backup/domain/entities/restore_notice.dart';
import 'package:inventrix/features/backup/domain/repositories/app_runtime.dart';
import 'package:inventrix/features/backup/domain/usecases/recover_restore.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// What the app is currently showing.
enum RuntimePhase {
  /// Not started yet.
  starting,

  /// Normal operation.
  running,

  /// A restore holds the app: services are stopped.
  restarting,

  /// The database could not be opened.
  failed,
}

/// Owns the app's service graph so a restore can stop everything, swap the
/// database files and start again.
///
/// It lives **outside** the service locator (the locator is reset while it
/// runs). `InventrixHost` rebuilds the UI whenever it changes.
final class InventrixRuntime extends ChangeNotifier implements AppRuntime {
  /// Creates the runtime on [locator] (default: the global one).
  InventrixRuntime({
    GetIt? locator,
    Future<DatabaseOpening> Function()? openDatabase,
  }) : _locator = locator ?? getIt,
       _openDatabase = openDatabase ?? _openSecureDatabase;

  final GetIt _locator;
  final Future<DatabaseOpening> Function() _openDatabase;
  String? _failureMessage;
  final Logger _log = Logger('InventrixRuntime');

  RuntimePhase _phase = RuntimePhase.starting;
  GoRouter? _router;
  int _generation = 0;
  RestoreNotice? _notice;

  /// Current phase.
  RuntimePhase get phase => _phase;

  /// Router of the running app.
  GoRouter? get router => _router;

  /// Settings (theme and formats) of the running app; `null` before start.
  SettingsCubit? get settings =>
      _phase == RuntimePhase.running ? _locator<SettingsCubit>() : null;

  /// User-safe explanation when [phase] is [RuntimePhase.failed] and the cause
  /// is known (for example a missing encryption key).
  String? get failureMessage => _failureMessage;

  /// Incremented on every start; used as the UI key so state never leaks
  /// from before a restore.
  int get generation => _generation;

  /// Returns the pending one-time notice and forgets it.
  RestoreNotice? takeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  @override
  Future<void> start() async {
    // A start that follows [shutDown] in the same process is a restore
    // starting the app again on the restored data (or on the old data after
    // an abort). It is not a new launch after a crash, and at that moment the
    // journal still says "swapping" until the restore commits. Running the
    // crash recovery here would undo the restore that is in progress.
    final restartInProcess = _phase == RuntimePhase.restarting;
    try {
      if (!restartInProcess) {
        // Before the database is opened: undo a restore that was
        // interrupted by a crash or a killed app.
        await RecoverInterruptedRestore(
          journal: FileRestoreJournalStore(getApplicationDocumentsDirectory),
          swapper: FileRestoreSwapper(),
        )();
      }
      _failureMessage = null;
      // Unlock (or create, or migrate) the encrypted database first. This
      // never deletes or resets anything when the key is missing or wrong.
      final opening = await _openDatabase();
      await configureDependencies(
        locator: _locator,
        runtime: this,
        session: opening.session,
      );
      await _locator<AppDatabase>().initialize();
      await opening.assertEncryptedOnDisk();
      try {
        _notice = await _locator<ReconcileRestoreJournal>()();
      } on Object catch (error, stackTrace) {
        // The history is informative; never block start-up on it.
        _log.warning('Could not reconcile restore journal', error, stackTrace);
      }
      try {
        // Theme and date/number styles must be known before the first frame.
        await _locator<SettingsCubit>().load();
      } on Object catch (error, stackTrace) {
        _log.warning('Could not load the settings', error, stackTrace);
      }
      _router = _locator<GoRouter>();
      _generation++;
      _phase = RuntimePhase.running;
      notifyListeners();
    } on DatabaseSecurityException catch (error) {
      _failureMessage = error.message;
      _phase = RuntimePhase.failed;
      notifyListeners();
      rethrow;
    } on Object {
      _phase = RuntimePhase.failed;
      notifyListeners();
      rethrow;
    }
  }

  @override
  Future<void> reportRestoreResult() async {
    if (_phase != RuntimePhase.running) {
      return;
    }
    try {
      final notice = await _locator<ReconcileRestoreJournal>()();
      if (notice != null) {
        _notice = notice;
        // The host shows the pending notice when it rebuilds.
        notifyListeners();
      }
    } on Object catch (error, stackTrace) {
      // Not fatal: the journal stays and the next launch reports it.
      _log.warning('Could not report the restore result', error, stackTrace);
    }
  }

  @override
  Future<void> shutDown() async {
    _phase = RuntimePhase.restarting;
    _router = null;
    notifyListeners();
    // Let the framework drop every widget that still talks to the database.
    try {
      await WidgetsBinding.instance.endOfFrame.timeout(
        const Duration(seconds: 2),
      );
    } on Object {
      // No frame in the background; the UI is replaced when it resumes.
    }
    await resetDependencies(locator: _locator);
  }
}

/// An unlocked database plus the check to run once it is open.
final class DatabaseOpening {
  /// Creates the result.
  const DatabaseOpening({
    required this.session,
    required this.assertEncryptedOnDisk,
  });

  /// Where the database lives and its key.
  final DatabaseSession session;

  /// Throws if the file on disk turns out not to be encrypted.
  final Future<void> Function() assertEncryptedOnDisk;
}

Future<DatabaseOpening> _openSecureDatabase() async {
  final documents = await getApplicationDocumentsDirectory();
  final opener = EncryptedDatabaseOpener(
    // Same file as before encryption existed, so existing data is found.
    path: p.join(documents.path, '${AppConstants.databaseName}.sqlite'),
    keys: SecretKeyManager(SecureStorageSecretStore()),
    gateway: const Sqlite3SqlcipherGateway(),
  );
  final session = await opener.open();
  return DatabaseOpening(
    session: session,
    assertEncryptedOnDisk: opener.assertEncryptedOnDisk,
  );
}
