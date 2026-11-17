/// Decides whether the owner should be reminded to export a backup.
abstract final class BackupReminder {
  /// Whether a reminder is due.
  ///
  /// [reminderDays] is the interval chosen in the settings (`0` = never
  /// remind). [lastExportedAt] is when a backup last left the app (shared or
  /// saved elsewhere); a backup that only exists inside the app does not
  /// survive an uninstall, so it does not count. With no export yet, a
  /// reminder is due as soon as reminders are on.
  static bool isDue({
    required int reminderDays,
    required DateTime? lastExportedAt,
    required DateTime now,
  }) {
    if (reminderDays <= 0) {
      return false;
    }
    if (lastExportedAt == null) {
      return true;
    }
    return now.difference(lastExportedAt) >= Duration(days: reminderDays);
  }
}
