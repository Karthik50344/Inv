import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';

/// Restores an archived supplier.
final class RestoreSupplier {
  /// Creates the use case.
  const RestoreSupplier({
    required SupplierRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final SupplierRepository _repository;
  final Clock _clock;

  /// Restores supplier [id]. Restoring an active supplier succeeds.
  Future<Result<void>> call(String id) async {
    final loaded = await _repository.getById(id);
    final supplier = loaded.valueOrNull;
    if (supplier == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    if (!supplier.isArchived) {
      return const Result.success(null);
    }
    return _repository.update(supplier.restored(_clock.now()));
  }
}
