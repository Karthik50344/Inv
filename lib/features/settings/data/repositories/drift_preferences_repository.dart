import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';
import 'package:inventrix/features/settings/domain/entities/setting_keys.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';

/// Stores [AppPreferences] as rows of `app_settings`.
///
/// A value that is missing or unreadable falls back to its default, so a
/// restored backup from an older version never blocks start-up.
final class DriftPreferencesRepository implements PreferencesRepository {
  /// Creates the repository.
  const DriftPreferencesRepository(this._db);

  final AppDatabase _db;

  static const List<String> _keys = [
    SettingKeys.themeMode,
    SettingKeys.dateStyle,
    SettingKeys.numberStyle,
    SettingKeys.purchaseApproval,
    SettingKeys.salesApproval,
    SettingKeys.defaultPaymentMethodId,
    SettingKeys.defaultTaxRateId,
    SettingKeys.defaultPriceIncludesTax,
    SettingKeys.backupReminderDays,
    SettingKeys.introSeen,
  ];

  @override
  Future<Result<AppPreferences>> load() => guardDatabase(() async {
    final rows = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.isIn(_keys))).get();
    final values = {for (final row in rows) row.key: row.value};
    final reminder = int.tryParse(values[SettingKeys.backupReminderDays] ?? '');
    return AppPreferences(
      theme: ThemePreference.parse(values[SettingKeys.themeMode]),
      dateStyle: DateStyle.parse(values[SettingKeys.dateStyle]),
      numberStyle: NumberStyle.parse(values[SettingKeys.numberStyle]),
      purchaseApprovalRequired: values[SettingKeys.purchaseApproval] == 'true',
      salesApprovalRequired: values[SettingKeys.salesApproval] == 'true',
      defaultPaymentMethodId: _nonBlank(
        values[SettingKeys.defaultPaymentMethodId],
      ),
      defaultTaxRateId: _nonBlank(values[SettingKeys.defaultTaxRateId]),
      defaultPriceIncludesTax:
          values[SettingKeys.defaultPriceIncludesTax] == 'true',
      backupReminderDays: AppPreferences.reminderChoices.contains(reminder)
          ? reminder!
          : 0,
      introSeen: values[SettingKeys.introSeen] == 'true',
    );
  });

  @override
  Future<Result<void>> save(AppPreferences preferences) => guardDatabase(
    () async {
      final now = toEpochMs(DateTime.now());
      final entries = <String, String?>{
        SettingKeys.themeMode: preferences.theme.name,
        SettingKeys.dateStyle: preferences.dateStyle.name,
        SettingKeys.numberStyle: preferences.numberStyle.name,
        SettingKeys.purchaseApproval: '${preferences.purchaseApprovalRequired}',
        SettingKeys.salesApproval: '${preferences.salesApprovalRequired}',
        SettingKeys.defaultPaymentMethodId: preferences.defaultPaymentMethodId,
        SettingKeys.defaultTaxRateId: preferences.defaultTaxRateId,
        SettingKeys.defaultPriceIncludesTax:
            '${preferences.defaultPriceIncludesTax}',
        SettingKeys.backupReminderDays: '${preferences.backupReminderDays}',
        SettingKeys.introSeen: '${preferences.introSeen}',
      };
      await _db.transaction(() async {
        for (final entry in entries.entries) {
          if (entry.value == null) {
            await (_db.delete(
              _db.appSettings,
            )..where((t) => t.key.equals(entry.key))).go();
          } else {
            await _db
                .into(_db.appSettings)
                .insertOnConflictUpdate(
                  AppSettingsCompanion(
                    key: Value(entry.key),
                    value: Value(entry.value!),
                    updatedAt: Value(now),
                  ),
                );
          }
        }
      });
    },
  );

  static String? _nonBlank(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}
