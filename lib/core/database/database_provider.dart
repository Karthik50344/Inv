import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/core/database/database_session.dart';
import 'package:inventrix/core/database/sqlcipher_gateway_impl.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

/// Opens the on-device encrypted SQLite connection
/// (`inventory_management.sqlite`) for an unlocked [session].
///
/// The key is applied by SQLCipher before drift touches the file, on every
/// connection. Tests pass their own in-memory executor to `AppDatabase`
/// instead.
QueryExecutor openAppDatabaseConnection(DatabaseSession session) {
  final hex = session.key.toHex();
  return driftDatabase(
    name: AppConstants.databaseName,
    native: DriftNativeOptions(
      databasePath: () async => session.path,
      setup: (CommonDatabase raw) => applyKey(raw, hex),
    ),
  );
}
