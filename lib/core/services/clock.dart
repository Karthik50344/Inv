/// Source of the current time (injectable for tests).
abstract interface class Clock {
  /// Current time in UTC.
  DateTime now();
}

/// [Clock] backed by the system clock.
final class SystemClock implements Clock {
  /// Creates a system clock.
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
