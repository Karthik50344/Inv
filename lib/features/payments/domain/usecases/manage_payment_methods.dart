import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/core/services/id_generator.dart';
import 'package:inventrix/core/validators/validators.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';

/// Creates payment methods.
final class CreatePaymentMethod {
  /// Creates the use case.
  const CreatePaymentMethod({
    required PaymentMethodRepository methods,
    required IdGenerator ids,
    required Clock clock,
  }) : _methods = methods,
       _ids = ids,
       _clock = clock;

  final PaymentMethodRepository _methods;
  final IdGenerator _ids;
  final Clock _clock;

  /// Creates a method named [name].
  Future<Result<PaymentMethod>> call(String name) async {
    final error = Validators.requiredText(
      name,
      label: 'Name',
      maxLength: 40,
    );
    if (error != null) {
      return Result.failure(
        ValidationFailure(error, fieldErrors: {'name': error}),
      );
    }
    final method = PaymentMethod(
      id: _ids.newId(),
      name: name.trim(),
      createdAt: _clock.now(),
    );
    final result = await _methods.create(method);
    final failure = result.failureOrNull;
    if (failure is DuplicateEntryFailure) {
      return const Result.failure(
        ValidationFailure(
          'A payment method with this name already exists.',
          fieldErrors: {'name': 'Already exists.'},
        ),
      );
    }
    return failure != null ? Result.failure(failure) : Result.success(method);
  }
}

/// Archives or restores a payment method. Methods are never deleted: past
/// payments keep a snapshot of the name.
final class SetPaymentMethodArchived {
  /// Creates the use case.
  const SetPaymentMethodArchived({
    required PaymentMethodRepository methods,
    required Clock clock,
  }) : _methods = methods,
       _clock = clock;

  final PaymentMethodRepository _methods;
  final Clock _clock;

  /// Archives ([archived] true) or restores the method.
  Future<Result<void>> call(String id, {required bool archived}) async {
    final loaded = await _methods.getById(id);
    final method = loaded.valueOrNull;
    if (method == null) {
      return Result.failure(loaded.failureOrNull!);
    }
    if (method.isArchived == archived) {
      return const Result.success(null);
    }
    return _methods.update(
      PaymentMethod(
        id: method.id,
        name: method.name,
        createdAt: method.createdAt,
        archivedAt: archived ? _clock.now() : null,
      ),
    );
  }
}
