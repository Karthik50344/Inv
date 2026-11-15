import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';

/// Persistence contract for tax rates.
abstract interface class TaxRateRepository {
  /// Lists tax rates ordered by name.
  Future<Result<List<TaxRate>>> list({bool includeArchived = false});

  /// Loads one tax rate; fails with `NotFoundFailure` if missing.
  Future<Result<TaxRate>> getById(String id);

  /// Whether an active tax rate with [name] exists (case-insensitive).
  Future<Result<bool>> nameExists(String name);

  /// Inserts a new tax rate.
  Future<Result<void>> create(TaxRate taxRate);
}
