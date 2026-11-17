import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';

/// The owner's everyday preferences. Nothing here changes stored financial
/// data: these settings only affect how the app looks and behaves from now on.
final class AppPreferences extends Equatable {
  /// Creates preferences; the defaults match a fresh install.
  const AppPreferences({
    this.theme = ThemePreference.system,
    this.dateStyle = DateStyle.longMonth,
    this.numberStyle = NumberStyle.indian,
    this.purchaseApprovalRequired = false,
    this.salesApprovalRequired = false,
    this.defaultPaymentMethodId,
    this.defaultTaxRateId,
    this.defaultPriceIncludesTax = false,
    this.backupReminderDays = 0,
  });

  /// Values offered for [backupReminderDays] (`0` switches reminders off).
  static const List<int> reminderChoices = [0, 7, 14, 30];

  /// Light, dark or follow the device.
  final ThemePreference theme;

  /// How dates are written.
  final DateStyle dateStyle;

  /// How numbers and money are written.
  final NumberStyle numberStyle;

  /// Whether purchases must be approved before posting.
  final bool purchaseApprovalRequired;

  /// Whether sales must be approved before posting.
  final bool salesApprovalRequired;

  /// Payment method preselected in payment and expense forms.
  final String? defaultPaymentMethodId;

  /// Tax rate preselected for new products.
  final String? defaultTaxRateId;

  /// Whether new products start with tax-inclusive prices.
  final bool defaultPriceIncludesTax;

  /// Days after which the backup screen asks for a fresh exported backup;
  /// `0` means no reminder.
  final int backupReminderDays;

  /// Copy with changes. Use the `clear...` flags to reset an optional id.
  AppPreferences copyWith({
    ThemePreference? theme,
    DateStyle? dateStyle,
    NumberStyle? numberStyle,
    bool? purchaseApprovalRequired,
    bool? salesApprovalRequired,
    String? defaultPaymentMethodId,
    bool clearDefaultPaymentMethod = false,
    String? defaultTaxRateId,
    bool clearDefaultTaxRate = false,
    bool? defaultPriceIncludesTax,
    int? backupReminderDays,
  }) => AppPreferences(
    theme: theme ?? this.theme,
    dateStyle: dateStyle ?? this.dateStyle,
    numberStyle: numberStyle ?? this.numberStyle,
    purchaseApprovalRequired:
        purchaseApprovalRequired ?? this.purchaseApprovalRequired,
    salesApprovalRequired: salesApprovalRequired ?? this.salesApprovalRequired,
    defaultPaymentMethodId: clearDefaultPaymentMethod
        ? null
        : defaultPaymentMethodId ?? this.defaultPaymentMethodId,
    defaultTaxRateId: clearDefaultTaxRate
        ? null
        : defaultTaxRateId ?? this.defaultTaxRateId,
    defaultPriceIncludesTax:
        defaultPriceIncludesTax ?? this.defaultPriceIncludesTax,
    backupReminderDays: backupReminderDays ?? this.backupReminderDays,
  );

  @override
  List<Object?> get props => [
    theme,
    dateStyle,
    numberStyle,
    purchaseApprovalRequired,
    salesApprovalRequired,
    defaultPaymentMethodId,
    defaultTaxRateId,
    defaultPriceIncludesTax,
    backupReminderDays,
  ];
}
