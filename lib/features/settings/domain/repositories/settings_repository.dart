import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// Read access to business settings needed by other features.
abstract interface class SettingsRepository {
  /// Returns the configured currency and decimal places.
  Future<Result<CurrencyConfig>> getCurrencyConfig();

  /// Whether purchases must be approved before they can be posted
  /// (default: `false`).
  Future<Result<bool>> isPurchaseApprovalRequired();

  /// Turns the purchase approval step on or off. Documents already past
  /// approval are unaffected.
  Future<Result<void>> setPurchaseApprovalRequired(bool value);

  /// Whether sales invoices must be approved before they can be posted
  /// (default: `false`).
  Future<Result<bool>> isSalesApprovalRequired();

  /// Turns the sales approval step on or off. Documents already past
  /// approval are unaffected.
  Future<Result<void>> setSalesApprovalRequired(bool value);

  /// The business identity printed on documents. Falls back to a
  /// placeholder name until the business profile is configured (Phase 11).
  Future<Result<BusinessProfile>> getBusinessProfile();
}
