import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';

/// Persistence contract for customers.
abstract interface class CustomerRepository {
  /// Lists customers ordered by name; [query] matches name, phone or email.
  Future<Result<List<Customer>>> search({
    String query = '',
    bool includeArchived = false,
  });

  /// Loads one customer; fails with `NotFoundFailure` if missing.
  Future<Result<Customer>> getById(String id);

  /// Inserts a new customer.
  Future<Result<void>> create(Customer customer);

  /// Replaces an existing customer (also used for archive/restore).
  Future<Result<void>> update(Customer customer);
}
