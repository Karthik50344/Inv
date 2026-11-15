import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';

/// Restores an archived customer.
final class RestoreCustomer {
  /// Creates the use case.
  const RestoreCustomer({
    required CustomerRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final CustomerRepository _repository;
  final Clock _clock;

  /// Restores customer [id]. Restoring an active customer succeeds.
  Future<Result<void>> call(String id) async {
    final loaded = await _repository.getById(id);
    final customer = loaded.valueOrNull;
    if (customer == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    if (!customer.isArchived) {
      return const Result.success(null);
    }
    return _repository.update(customer.restored(_clock.now()));
  }
}
