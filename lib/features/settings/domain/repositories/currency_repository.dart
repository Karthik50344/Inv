import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/money_lock.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// Persistence contract for the active currency.
abstract interface class CurrencyRepository {
  /// Reports which stored amounts depend on the current currency.
  Future<Result<MoneyLock>> moneyLock();

  /// Saves the currency and its decimal places.
  Future<Result<void>> save(CurrencyConfig config);
}
