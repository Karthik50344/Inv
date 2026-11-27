import 'dart:ui';

import 'package:inventrix/app/runtime/inventrix_host.dart';
import 'package:inventrix/app/runtime/inventrix_runtime.dart';
import 'package:inventrix/app/runtime/startup_failure_app.dart';
import 'package:inventrix/core/logging/app_logger.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';

export 'package:inventrix/app/runtime/startup_failure_app.dart';

/// Initializes logging, error handling, dependencies and the database, then
/// starts the app. If initialization fails, a recovery screen is shown and
/// no data is deleted or reset.
///
/// The service graph is owned by [InventrixRuntime] so that restoring a
/// backup can stop it, swap the database files and start it again.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.init();
  final log = Logger('bootstrap');

  FlutterError.onError = (details) {
    log.severe('Flutter framework error', details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    log.severe('Uncaught error', error, stackTrace);
    return true;
  };

  final runtime = InventrixRuntime();
  try {
    await runtime.start();
    runApp(InventrixHost(runtime: runtime));
  } on Object catch (error, stackTrace) {
    log.severe('Startup failed', error, stackTrace);
    runApp(StartupFailureApp(message: runtime.failureMessage));
  }
}
