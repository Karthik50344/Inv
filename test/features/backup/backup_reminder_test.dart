import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/features/backup/domain/services/backup_reminder.dart';

void main() {
  final now = DateTime.utc(2026, 11, 16, 10);

  test('never due when reminders are off', () {
    expect(
      BackupReminder.isDue(reminderDays: 0, lastExportedAt: null, now: now),
      isFalse,
    );
  });

  test('due when nothing was ever exported', () {
    expect(
      BackupReminder.isDue(reminderDays: 7, lastExportedAt: null, now: now),
      isTrue,
    );
  });

  test('due exactly at the interval, not before', () {
    expect(
      BackupReminder.isDue(
        reminderDays: 7,
        lastExportedAt: now.subtract(const Duration(days: 7)),
        now: now,
      ),
      isTrue,
    );
    expect(
      BackupReminder.isDue(
        reminderDays: 7,
        lastExportedAt: now.subtract(const Duration(days: 6, hours: 23)),
        now: now,
      ),
      isFalse,
    );
  });
}
