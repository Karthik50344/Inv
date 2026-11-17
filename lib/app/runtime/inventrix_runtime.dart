import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/di/injection.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/features/backup/data/services/file_restore_journal_store.dart';
import 'package:inventrix/features/backup/data/services/file_restore_swapper.dart';
import 'package:inventrix/features/backup/domain/entities/restore_notice.dart';
import 'package:inventrix/features/backup/domain/repositories/app_runtime.dart';
import 'package:inventrix/features/backup/domain/usecases/recover_restore.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:logging/logging.dart';
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
  InventrixRuntime({GetIt? locator}) : _locator = locator ?? getIt;

  final GetIt _locator;
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
    try {
      // Before the database is opened: undo a restore that was interrupted.
      await RecoverInterruptedRestore(
        journal: FileRestoreJournalStore(getApplicationDocumentsDirectory),
        swapper: FileRestoreSwapper(),
      )();
      await configureDependencies(locator: _locator, runtime: this);
      await _locator<AppDatabase>().initialize();
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
    } on Object {
      _phase = RuntimePhase.failed;
      notifyListeners();
      rethrow;
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
