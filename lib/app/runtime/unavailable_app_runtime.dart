import 'package:inventrix/features/backup/domain/repositories/app_runtime.dart';

/// [AppRuntime] used where no real runtime exists (tests). Restoring fails
/// before any file is touched.
final class UnavailableAppRuntime implements AppRuntime {
  /// Creates the runtime.
  const UnavailableAppRuntime();

  @override
  Future<void> shutDown() =>
      throw StateError('Restoring is not available in this environment.');

  @override
  Future<void> start() =>
      throw StateError('Restoring is not available in this environment.');

  @override
  Future<void> reportRestoreResult() async {}
}
