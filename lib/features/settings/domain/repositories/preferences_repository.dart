import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';

/// Persistence contract for [AppPreferences].
///
/// To change one preference, read, copy and save inside one
/// `TransactionRunner.runResult` so two screens cannot overwrite each other.
abstract interface class PreferencesRepository {
  /// Loads the preferences; anything never saved has its default.
  Future<Result<AppPreferences>> load();

  /// Saves all preferences.
  Future<Result<void>> save(AppPreferences preferences);
}
