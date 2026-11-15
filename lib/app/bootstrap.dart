import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/app.dart';
import 'package:inventrix/app/di/injection.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/logging/app_logger.dart';
import 'package:logging/logging.dart';

/// Initializes logging, error handling, dependencies and the database, then
/// starts the app. If initialization fails, a recovery screen is shown and
/// no data is deleted or reset.
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

  try {
    await configureDependencies();
    await getIt<AppDatabase>().initialize();
    runApp(InventrixApp(router: getIt<GoRouter>()));
  } on Object catch (error, stackTrace) {
    log.severe('Startup failed', error, stackTrace);
    runApp(const StartupFailureApp());
  }
}

/// Shown when the database cannot be opened or migrated.
class StartupFailureApp extends StatelessWidget {
  /// Creates the recovery screen.
  const StartupFailureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "${AppConstants.appName} couldn't open its database. "
              'No data has been deleted or reset. Please restart the app; if '
              'the problem continues, contact support before reinstalling.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
