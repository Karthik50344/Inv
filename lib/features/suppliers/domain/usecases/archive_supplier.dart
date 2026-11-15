import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';

/// Archives a supplier (history is kept).
final class ArchiveSupplier {
  /// Creates the use case.
  const ArchiveSupplier({
    required SupplierRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final SupplierRepository _repository;
  final Clock _clock;

  /// Archives supplier [id]. Archiving an archived supplier succeeds.
  Future<Result<void>> call(String id) async {
    final loaded = await _repository.getById(id);
    final supplier = loaded.valueOrNull;
    if (supplier == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    if (supplier.isArchived) {
      return const Result.success(null);
    }
    return _repository.update(supplier.archived(_clock.now()));
  }
}
