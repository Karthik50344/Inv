import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/sales/domain/entities/customer_receivable.dart';
import 'package:inventrix/features/sales/domain/usecases/get_customer_receivable.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/customers/domain/usecases/archive_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/restore_customer.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';

/// State of the customer detail screen.
final class CustomerDetailState extends Equatable {
  /// Creates a state.
  const CustomerDetailState({
    this.status = DetailStatus.loading,
    this.customer,
    this.receivable,
    this.message,
  });

  /// Load status.
  final DetailStatus status;

  /// The customer.
  final Customer? customer;

  /// What this customer owes the business (`null` when unavailable).
  final CustomerReceivable? receivable;

  /// One-shot user-facing message.
  final String? message;

  @override
  List<Object?> get props => [status, customer, receivable, message];
}

/// Loads one customer by id.
class CustomerDetailCubit extends Cubit<CustomerDetailState> {
  /// Creates the cubit.
  CustomerDetailCubit({
    required CustomerRepository repository,
    required ArchiveCustomer archiveCustomer,
    required RestoreCustomer restoreCustomer,
    GetCustomerReceivable? getReceivable,
  }) : _repository = repository,
       _archive = archiveCustomer,
       _restore = restoreCustomer,
       _getReceivable = getReceivable,
       super(const CustomerDetailState());

  final CustomerRepository _repository;
  final GetCustomerReceivable? _getReceivable;
  final ArchiveCustomer _archive;
  final RestoreCustomer _restore;
  String? _id;

  /// Loads customer [id]; unknown ids end in [DetailStatus.notFound].
  Future<void> load(String id) async {
    _id = id;
    emit(const CustomerDetailState());
    final result = await _repository.getById(id);
    final receivable = await _getReceivable?.call(id);
    if (isClosed) {
      return;
    }
    result.when(
      success: (value) => emit(
        CustomerDetailState(
          status: DetailStatus.loaded,
          customer: value,
          receivable: receivable?.valueOrNull,
        ),
      ),
      failure: (failure) => emit(
        CustomerDetailState(
          status: failure is NotFoundFailure
              ? DetailStatus.notFound
              : DetailStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }

  /// Archives the customer and reloads.
  Future<void> archive() => _toggle(archive: true);

  /// Restores the customer and reloads.
  Future<void> restore() => _toggle(archive: false);

  Future<void> _toggle({required bool archive}) async {
    final id = _id;
    if (id == null) {
      return;
    }
    final result = archive ? await _archive(id) : await _restore(id);
    final failure = result.failureOrNull;
    if (failure != null && !isClosed) {
      emit(
        CustomerDetailState(
          status: state.status,
          customer: state.customer,
          receivable: state.receivable,
          message: failure.userMessage,
        ),
      );
      return;
    }
    await load(id);
  }
}
