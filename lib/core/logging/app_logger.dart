import 'dart:developer' as developer;

import 'package:logging/logging.dart';

/// Configures the `logging` package to forward records to `dart:developer`.
abstract final class AppLogger {
  static bool _initialized = false;

  /// Installs the log listener once. Safe to call repeatedly.
  static void init({Level level = Level.INFO}) {
    Logger.root.level = level;
    if (_initialized) {
      return;
    }
    _initialized = true;
    Logger.root.onRecord.listen((record) {
      developer.log(
        record.message,
        time: record.time,
        level: record.level.value,
        name: record.loggerName,
        error: record.error,
        stackTrace: record.stackTrace,
      );
    });
  }
}
