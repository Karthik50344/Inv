import 'package:equatable/equatable.dart';
import 'package:inventrix/features/settings/domain/entities/app_preferences.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/features/settings/domain/entities/money_lock.dart';
import 'package:inventrix/features/settings/domain/entities/numbering_settings.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Everything the settings screens show.
final class SettingsState extends Equatable {
  /// Creates a state.
  const SettingsState({
    this.status = ViewStatus.initial,
    this.business,
    this.currency = const CurrencyConfig(currencyCode: 'INR', decimalPlaces: 2),
    this.moneyLock = MoneyLock.none,
    this.preferences = const AppPreferences(),
    this.numbering = const NumberingSettings(),
    this.fieldErrors = const {},
    this.message,
    this.messageSerial = 0,
    this.saving = false,
  });

  /// Loading status of the first load.
  final ViewStatus status;

  /// The saved business profile; `null` until the owner enters one.
  final BusinessProfile? business;

  /// Active currency.
  final CurrencyConfig currency;

  /// Why the currency may be locked.
  final MoneyLock moneyLock;

  /// Everyday preferences.
  final AppPreferences preferences;

  /// Document prefixes, padding and counters.
  final NumberingSettings numbering;

  /// Messages per form field after a failed save.
  final Map<String, String> fieldErrors;

  /// Message for the user (error or confirmation).
  final String? message;

  /// Incremented with every [message] so that the same text can be shown
  /// twice in a row.
  final int messageSerial;

  /// Whether a save is running.
  final bool saving;

  /// Copy with changes. [clearErrors] empties [fieldErrors]; a new [message]
  /// bumps [messageSerial].
  SettingsState copyWith({
    ViewStatus? status,
    BusinessProfile? business,
    CurrencyConfig? currency,
    MoneyLock? moneyLock,
    AppPreferences? preferences,
    NumberingSettings? numbering,
    Map<String, String>? fieldErrors,
    String? message,
    bool? saving,
  }) => SettingsState(
    status: status ?? this.status,
    business: business ?? this.business,
    currency: currency ?? this.currency,
    moneyLock: moneyLock ?? this.moneyLock,
    preferences: preferences ?? this.preferences,
    numbering: numbering ?? this.numbering,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    message: message ?? this.message,
    messageSerial: message == null ? messageSerial : messageSerial + 1,
    saving: saving ?? this.saving,
  );

  @override
  List<Object?> get props => [
    status,
    business,
    currency,
    moneyLock,
    preferences,
    numbering,
    fieldErrors,
    message,
    messageSerial,
    saving,
  ];
}
