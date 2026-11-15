import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';

/// Persistence contract for suppliers.
abstract interface class SupplierRepository {
  /// Lists suppliers ordered by name; [query] matches name, phone or email.
  Future<Result<List<Supplier>>> search({
    String query = '',
    bool includeArchived = false,
  });

  /// Loads one supplier; fails with `NotFoundFailure` if missing.
  Future<Result<Supplier>> getById(String id);

  /// Inserts a new supplier.
  Future<Result<void>> create(Supplier supplier);

  /// Replaces an existing supplier (also used for archive/restore).
  Future<Result<void>> update(Supplier supplier);
}
