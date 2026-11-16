/// Lets a restore stop the app's services, swap files, and start them again.
abstract interface class AppRuntime {
  /// Closes the database and every service that holds it, and replaces the
  /// UI with a neutral "working" screen. Nothing may use the database until
  /// [start] has completed.
  Future<void> shutDown();

  /// Opens the database again (running migrations), re-creates every
  /// service and shows the app. Throws if the database cannot be opened.
  Future<void> start();
}
