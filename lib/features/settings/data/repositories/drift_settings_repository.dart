import 'package:drift/drift.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/database/database_failure_mapper.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/settings/domain/entities/business_profile.dart';
import 'package:inventrix/features/settings/domain/entities/setting_keys.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

final RegExp _currencyCode = RegExp(r'^[A-Z]{3}$');

/// Reads settings from the `app_settings` table.
final class DriftSettingsRepository implements SettingsRepository {
  /// Creates the repository.
  const DriftSettingsRepository(this._db);

  final AppDatabase _db;

  @override
  Future<Result<CurrencyConfig>> getCurrencyConfig() => guardDatabase(() async {
    final rows =
        await (_db.select(_db.appSettings)..where(
              (t) => t.key.isIn([
                SettingKeys.currencyCode,
                SettingKeys.currencyDecimalPlaces,
              ]),
            ))
            .get();
    final values = {for (final row in rows) row.key: row.value};
    final code =
        values[SettingKeys.currencyCode] ?? AppConstants.defaultCurrencyCode;
    final places = values[SettingKeys.currencyDecimalPlaces] == null
        ? AppConstants.defaultCurrencyDecimalPlaces
        : int.tryParse(values[SettingKeys.currencyDecimalPlaces]!);
    if (!_currencyCode.hasMatch(code) ||
        places == null ||
        places < 0 ||
        places > 4) {
      throw const FailureException(
        DatabaseFailure('Currency settings are invalid.'),
      );
    }
    return CurrencyConfig(currencyCode: code, decimalPlaces: places);
  });

  static const String _purchaseApprovalKey = SettingKeys.purchaseApproval;

  @override
  Future<Result<bool>> isPurchaseApprovalRequired() => guardDatabase(() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(_purchaseApprovalKey))).getSingleOrNull();
    return row?.value == 'true';
  });

  @override
  Future<Result<void>> setPurchaseApprovalRequired(bool value) =>
      guardDatabase(() async {
        await _db
            .into(_db.appSettings)
            .insertOnConflictUpdate(
              AppSettingsCompanion(
                key: const Value(_purchaseApprovalKey),
                value: Value(value ? 'true' : 'false'),
                updatedAt: Value(toEpochMs(DateTime.now())),
              ),
            );
      });

  static const String _salesApprovalKey = SettingKeys.salesApproval;

  @override
  Future<Result<bool>> isSalesApprovalRequired() => guardDatabase(() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(_salesApprovalKey))).getSingleOrNull();
    return row?.value == 'true';
  });

  @override
  Future<Result<void>> setSalesApprovalRequired(bool value) =>
      guardDatabase(() async {
        await _db
            .into(_db.appSettings)
            .insertOnConflictUpdate(
              AppSettingsCompanion(
                key: const Value(_salesApprovalKey),
                value: Value(value ? 'true' : 'false'),
                updatedAt: Value(toEpochMs(DateTime.now())),
              ),
            );
      });

  @override
  Future<Result<BusinessProfile>> getBusinessProfile() =>
      guardDatabase(() async {
        final row =
            await (_db.select(_db.businessProfiles)
                  ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
                  ..limit(1))
                .getSingleOrNull();
        if (row == null || row.name.trim().isEmpty) {
          return BusinessProfile.placeholder;
        }
        return BusinessProfile(
          name: row.name,
          address: row.address,
          phone: row.phone,
          email: row.email,
          taxId: row.taxId,
          logoPath: row.logoPath,
        );
      });
}
