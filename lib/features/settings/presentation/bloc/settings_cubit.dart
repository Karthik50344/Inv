import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/formatters/display_formats.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile_input.dart';
import 'package:inventrix/features/settings/domain/repositories/business_profile_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/currency_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/logo_storage.dart';
import 'package:inventrix/features/settings/domain/repositories/numbering_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/settings/domain/usecases/change_currency.dart';
import 'package:inventrix/features/settings/domain/usecases/save_business_profile.dart';
import 'package:inventrix/features/settings/domain/usecases/save_numbering.dart';
import 'package:inventrix/features/settings/domain/usecases/update_preferences.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/shared/domain/services/document_kind.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Drives the settings screens and tells the rest of the app about
/// display preferences (theme, date and number styles).
///
/// One instance lives as long as the app's service graph: it is created
/// before the first screen so the saved theme and formats apply from the
/// first frame.
class SettingsCubit extends Cubit<SettingsState> {
  /// Creates the cubit.
  SettingsCubit({
    required PreferencesRepository preferences,
    required BusinessProfileRepository business,
    required CurrencyRepository currencies,
    required SettingsRepository settings,
    required NumberingRepository numbering,
    required LogoStorage logos,
    required SaveBusinessProfile saveBusinessProfile,
    required ChangeCurrency changeCurrency,
    required UpdatePreferences updatePreferences,
    required SaveNumbering saveNumbering,
    required SetNextDocumentNumber setNextDocumentNumber,
  }) : _preferences = preferences,
       _business = business,
       _currencies = currencies,
       _settings = settings,
       _numbering = numbering,
       _logos = logos,
       _saveBusinessProfile = saveBusinessProfile,
       _changeCurrency = changeCurrency,
       _updatePreferences = updatePreferences,
       _saveNumbering = saveNumbering,
       _setNextNumber = setNextDocumentNumber,
       super(const SettingsState());

  final PreferencesRepository _preferences;
  final BusinessProfileRepository _business;
  final CurrencyRepository _currencies;
  final SettingsRepository _settings;
  final NumberingRepository _numbering;
  final LogoStorage _logos;
  final SaveBusinessProfile _saveBusinessProfile;
  final ChangeCurrency _changeCurrency;
  final UpdatePreferences _updatePreferences;
  final SaveNumbering _saveNumbering;
  final SetNextDocumentNumber _setNextNumber;

  /// Loads every setting. With [silent] the screen keeps showing what it
  /// has while the data is refreshed.
  Future<void> load({bool silent = false}) async {
    if (!silent || state.status != ViewStatus.loaded) {
      emit(state.copyWith(status: ViewStatus.loading));
    }
    final preferences = await _preferences.load();
    final business = await _business.find();
    final currency = await _settings.getCurrencyConfig();
    final lock = await _currencies.moneyLock();
    final numbering = await _numbering.load();
    if (isClosed) {
      return;
    }
    final failure =
        preferences.failureOrNull ??
        business.failureOrNull ??
        currency.failureOrNull ??
        lock.failureOrNull ??
        numbering.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    _applyDisplay(preferences.valueOrNull!);
    emit(
      SettingsState(
        status: ViewStatus.loaded,
        business: business.valueOrNull,
        currency: currency.valueOrNull!,
        moneyLock: lock.valueOrNull!,
        preferences: preferences.valueOrNull!,
        numbering: numbering.valueOrNull!,
        messageSerial: state.messageSerial,
      ),
    );
  }

  void _applyDisplay(AppPreferences preferences) => DisplayFormats.apply(
    dateStyle: preferences.dateStyle,
    numberStyle: preferences.numberStyle,
  );

  /// Copies a picked image into app storage; returns its stored path.
  Future<Result<String>> storeLogo(String sourcePath) async {
    final result = await _logos.store(sourcePath);
    final failure = result.failureOrNull;
    if (failure != null && !isClosed) {
      emit(state.copyWith(message: failure.userMessage));
    }
    return result;
  }

  /// Absolute path of a stored logo, for display.
  Future<String> resolveLogoPath(String relativePath) =>
      _logos.resolvePath(relativePath);

  /// Saves the business profile. Returns whether it was saved.
  Future<bool> saveBusiness(BusinessProfileInput input) async {
    emit(state.copyWith(saving: true, fieldErrors: const {}));
    final result = await _saveBusinessProfile(input);
    if (isClosed) {
      return result.isSuccess;
    }
    final profile = result.valueOrNull;
    if (profile != null) {
      emit(
        state.copyWith(
          business: profile,
          saving: false,
          message: 'Business profile saved.',
        ),
      );
      return true;
    }
    _emitFailure(result.failureOrNull!);
    return false;
  }

  /// Changes the currency. Returns whether it was saved.
  Future<bool> saveCurrency({
    required String code,
    required int decimalPlaces,
  }) async {
    emit(state.copyWith(saving: true, fieldErrors: const {}));
    final result = await _changeCurrency(
      code: code,
      decimalPlaces: decimalPlaces,
    );
    if (isClosed) {
      return result.isSuccess;
    }
    final config = result.valueOrNull;
    if (config != null) {
      final lock = await _currencies.moneyLock();
      emit(
        state.copyWith(
          currency: config,
          moneyLock: lock.valueOrNull,
          saving: false,
          message: 'Currency saved.',
        ),
      );
      return true;
    }
    _emitFailure(result.failureOrNull!);
    return false;
  }

  /// Saves document prefixes and padding. Returns whether they were saved.
  Future<bool> saveNumbering({
    required Map<DocumentKind, String> prefixes,
    required int padding,
  }) async {
    emit(state.copyWith(saving: true, fieldErrors: const {}));
    final result = await _saveNumbering(prefixes: prefixes, padding: padding);
    if (isClosed) {
      return result.isSuccess;
    }
    final saved = result.valueOrNull;
    if (saved != null) {
      emit(
        state.copyWith(
          numbering: saved,
          saving: false,
          message: 'Numbering saved.',
        ),
      );
      return true;
    }
    _emitFailure(result.failureOrNull!);
    return false;
  }

  /// Sets the number of the next document of [kind]. Returns whether it was
  /// saved.
  Future<bool> setNextNumber(DocumentKind kind, String text) async {
    emit(state.copyWith(saving: true, fieldErrors: const {}));
    final result = await _setNextNumber(kind, text);
    if (isClosed) {
      return result.isSuccess;
    }
    final saved = result.valueOrNull;
    if (saved != null) {
      emit(
        state.copyWith(
          numbering: saved,
          saving: false,
          message: 'Next ${kind.label.toLowerCase()} number saved.',
        ),
      );
      return true;
    }
    _emitFailure(result.failureOrNull!);
    return false;
  }

  /// Chooses light, dark or system theme.
  Future<void> setTheme(ThemePreference theme) =>
      _update((p) => p.copyWith(theme: theme));

  /// Chooses how dates are written.
  Future<void> setDateStyle(DateStyle style) =>
      _update((p) => p.copyWith(dateStyle: style));

  /// Chooses how numbers are written.
  Future<void> setNumberStyle(NumberStyle style) =>
      _update((p) => p.copyWith(numberStyle: style));

  /// Turns the purchase approval step on or off.
  Future<void> setPurchaseApproval({required bool required}) =>
      _update((p) => p.copyWith(purchaseApprovalRequired: required));

  /// Turns the sales approval step on or off.
  Future<void> setSalesApproval({required bool required}) =>
      _update((p) => p.copyWith(salesApprovalRequired: required));

  /// Sets the backup reminder interval in days (`0` = off).
  Future<void> setBackupReminderDays(int days) =>
      _update((p) => p.copyWith(backupReminderDays: days));

  /// Remembers that the introduction was completed or skipped.
  Future<void> markIntroSeen() => _update((p) => p.copyWith(introSeen: true));

  Future<void> _update(
    AppPreferences Function(AppPreferences current) change,
  ) async {
    final result = await _updatePreferences(change);
    if (isClosed) {
      return;
    }
    final updated = result.valueOrNull;
    if (updated == null) {
      emit(state.copyWith(message: result.failureOrNull!.userMessage));
      return;
    }
    _applyDisplay(updated);
    emit(state.copyWith(preferences: updated));
  }

  void _emitFailure(Failure failure) => emit(
    state.copyWith(
      saving: false,
      fieldErrors: failure is ValidationFailure ? failure.fieldErrors : null,
      message: failure.userMessage,
    ),
  );
}
