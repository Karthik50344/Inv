import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/sales/domain/entities/customer_receivable.dart';
import 'package:inventrix/features/sales/domain/repositories/sales_repository.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';

/// Computes what the business owes a customer: the opening balance plus the
/// customer's posted sale invoices (payments arrive in Phase 6).
final class GetCustomerReceivable {
  /// Creates the use case.
  const GetCustomerReceivable({
    required SalesRepository sales,
    required CustomerRepository customers,
  }) : _sales = sales,
       _customers = customers;

  final SalesRepository _sales;
  final CustomerRepository _customers;

  /// Returns the receivable of customer [customerId].
  Future<Result<CustomerReceivable>> call(String customerId) async {
    final customer = await _customers.getById(customerId);
    final found = customer.valueOrNull;
    if (found == null) {
      return Result.failure(customer.failureOrNull!);
    }
    final total = await _sales.postedTotalForCustomer(customerId);
    final sales = total.valueOrNull;
    if (sales == null) {
      return Result.failure(total.failureOrNull!);
    }
    return Result.success(
      CustomerReceivable(
        openingBalance: found.openingBalance,
        sales: sales,
      ),
    );
  }
}
