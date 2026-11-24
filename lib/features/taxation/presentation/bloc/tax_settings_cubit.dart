import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_config.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_configuration.dart';
import 'package:inventrix/features/taxation/domain/entities/tax_preferences.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_config_repository.dart';
import 'package:inventrix/features/taxation/domain/repositories/tax_repository.dart';
import 'package:inventrix/features/taxation/domain/usecases/tax_config_editor.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the tax settings screens.
final class TaxSettingsState extends Equatable {
  /// Creates the state.
  const TaxSettingsState({
    this.status = ViewStatus.initial,
    this.configuration,
    this.preferences = const TaxPreferences(),
    this.currencyDecimals = 2,
    this.currencyCode = '',
    this.message,
    this.messageSerial = 0,
    this.error,
  });

  /// Loading state.
  final ViewStatus status;

  /// Everything that is configured.
  final TaxConfiguration? configuration;

  /// Business-level preferences.
  final TaxPreferences preferences;

  /// Decimal places of the active currency (for fixed amounts).
  final int currencyDecimals;

  /// Active currency code.
  final String currencyCode;

  /// A short result message.
  final String? message;

  /// Changes with every message.
  final int messageSerial;

  /// A readable load error.
  final String? error;

  @override
  List<Object?> get props => [
    status,
    configuration,
    preferences,
    currencyDecimals,
    currencyCode,
    message,
    messageSerial,
    error,
  ];
}

/// Loads and edits the tax configuration.
class TaxSettingsCubit extends Cubit<TaxSettingsState> {
  /// Creates the cubit.
  TaxSettingsCubit({
    required TaxRepository read,
    required TaxPreferencesRepository preferences,
    required SettingsRepository settings,
    required TaxConfigEditor editor,
  }) : _read = read,
       _preferences = preferences,
       _settings = settings,
       _editor = editor,
       super(const TaxSettingsState());

  final TaxRepository _read;
  final TaxPreferencesRepository _preferences;
  final SettingsRepository _settings;
  final TaxConfigEditor _editor;

  /// A new id for a record about to be created.
  String newId() => _editor.newId();

  /// Loads (or reloads) everything.
  Future<void> load() async {
    if (state.configuration == null) {
      emit(const TaxSettingsState(status: ViewStatus.loading));
    }
    final config = await _read.loadConfiguration();
    final value = config.valueOrNull;
    if (value == null) {
      emit(
        TaxSettingsState(
          status: ViewStatus.failure,
          error: config.failureOrNull?.message ?? 'Could not load the tax settings.',
        ),
      );
      return;
    }
    final prefs = (await _preferences.load()).valueOrNull ?? const TaxPreferences();
    final currency = (await _settings.getCurrencyConfig()).valueOrNull;
    emit(
      TaxSettingsState(
        status: ViewStatus.loaded,
        configuration: value,
        preferences: prefs,
        currencyDecimals: currency?.decimalPlaces ?? 2,
        currencyCode: currency?.currencyCode ?? '',
        messageSerial: state.messageSerial,
      ),
    );
  }

  /// Saves a regime. Returns the failure (with field errors) or `null`.
  Future<Failure?> saveRegime(TaxRegime r) => _run(() => _editor.saveRegime(r), 'Tax system saved.');

  /// Saves a place.
  Future<Failure?> saveJurisdiction(TaxJurisdiction j) => _run(() => _editor.saveJurisdiction(j), 'Place saved.');

  /// Saves a category.
  Future<Failure?> saveCategory(TaxCategory c) => _run(() => _editor.saveCategory(c), 'Tax category saved.');

  /// Saves a profile.
  Future<Failure?> saveProfile(TaxProfile p) => _run(() => _editor.saveProfile(p), 'Tax profile saved.');

  /// Saves an override.
  Future<Failure?> saveOverride(TaxOverride o) => _run(() => _editor.saveOverride(o), 'Override saved.');

  /// Saves a rule.
  Future<Failure?> saveRule(TaxRule r) => _run(() => _editor.saveRule(r), 'Tax rule saved.');

  /// Saves a component.
  Future<Failure?> saveComponent(TaxComponent c) => _run(() => _editor.saveComponent(c), 'Tax component saved.');

  /// Saves the preferences.
  Future<Failure?> savePreferences(TaxPreferences p) =>
      _run(() => _editor.savePreferences(p), 'Preferences saved.');

  /// Switches a record on or off.
  Future<Failure?> setActive(TaxConfigKind kind, String id, {required bool active}) => _run(
    () => _editor.setActive(kind, id, active: active),
    active ? 'Switched on.' : 'Switched off.',
  );

  Future<Failure?> _run(Future<Result<Object?>> Function() action, String done) async {
    final result = await action();
    if (result.isFailure) {
      final failure = result.failureOrNull!;
      if (failure is! ValidationFailure || failure.fieldErrors.isEmpty) {
        emit(_withMessage(failure.message));
      }
      return failure;
    }
    await load();
    emit(_withMessage(done));
    return null;
  }

  TaxSettingsState _withMessage(String message) => TaxSettingsState(
    status: state.status,
    configuration: state.configuration,
    preferences: state.preferences,
    currencyDecimals: state.currencyDecimals,
    currencyCode: state.currencyCode,
    message: message,
    messageSerial: state.messageSerial + 1,
    error: state.error,
  );
}
