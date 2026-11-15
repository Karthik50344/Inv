import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:inventrix/core/constants/app_constants.dart';

/// Opens the on-device SQLite connection (`inventory_management.sqlite`).
///
/// Tests pass their own in-memory executor to `AppDatabase` instead.
QueryExecutor openAppDatabaseConnection() =>
    driftDatabase(name: AppConstants.databaseName);
