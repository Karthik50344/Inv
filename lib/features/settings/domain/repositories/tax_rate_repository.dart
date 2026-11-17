import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';

/// Persistence contract for tax rates.
abstract interface class TaxRateRepository {
  /// Lists tax rates ordered by name.
  Future<Result<List<TaxRate>>> list({bool includeArchived = false});

  /// Loads one tax rate; fails with `NotFoundFailure` if missing.
  Future<Result<TaxRate>> getById(String id);

  /// Whether an active tax rate with [name] exists (case-insensitive),
  /// ignoring the rate with id [excludingId] (used when renaming).
  Future<Result<bool>> nameExists(String name, {String? excludingId});

  /// Whether any product or expense refers to the tax rate [id].
  Future<Result<bool>> isInUse(String id);

  /// Inserts a new tax rate.
  Future<Result<void>> create(TaxRate taxRate);

  /// Replaces a tax rate (rename, change, archive or restore).
  Future<Result<void>> update(TaxRate taxRate);
}
