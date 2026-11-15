import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/purchases/domain/entities/supplier_payable.dart';
import 'package:inventrix/features/purchases/domain/repositories/purchase_repository.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';

/// Computes what the business owes a supplier: the opening balance plus the
/// supplier's posted purchase invoices (payments arrive in Phase 6).
final class GetSupplierPayable {
  /// Creates the use case.
  const GetSupplierPayable({
    required PurchaseRepository purchases,
    required SupplierRepository suppliers,
  }) : _purchases = purchases,
       _suppliers = suppliers;

  final PurchaseRepository _purchases;
  final SupplierRepository _suppliers;

  /// Returns the payable of supplier [supplierId].
  Future<Result<SupplierPayable>> call(String supplierId) async {
    final supplier = await _suppliers.getById(supplierId);
    final found = supplier.valueOrNull;
    if (found == null) {
      return Result.failure(supplier.failureOrNull!);
    }
    final total = await _purchases.postedTotalForSupplier(supplierId);
    final purchases = total.valueOrNull;
    if (purchases == null) {
      return Result.failure(total.failureOrNull!);
    }
    return Result.success(
      SupplierPayable(
        openingBalance: found.openingBalance,
        purchases: purchases,
      ),
    );
  }
}
