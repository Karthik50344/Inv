import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/customers/domain/usecases/archive_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/restore_customer.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_event.dart';
import 'package:inventrix/features/customers/presentation/bloc/customer_state.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Lists, searches and archives customers.
class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  /// Creates the bloc.
  CustomerBloc({
    required CustomerRepository repository,
    required ArchiveCustomer archiveCustomer,
    required RestoreCustomer restoreCustomer,
  }) : _repository = repository,
       _archive = archiveCustomer,
       _restore = restoreCustomer,
       super(const CustomerState()) {
    on<CustomersStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<CustomersRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<CustomersSearchChanged>((event, emit) {
      emit(state.copyWith(query: event.query));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<CustomersArchivedFilterChanged>((event, emit) {
      emit(state.copyWith(includeArchived: event.includeArchived));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<CustomerArchiveToggled>(
      _onArchiveToggled,
      transformer: sequentialTransformer(),
    );
  }

  final CustomerRepository _repository;
  final ArchiveCustomer _archive;
  final RestoreCustomer _restore;

  Future<void> _load(Emitter<CustomerState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _repository.search(
      query: state.query,
      includeArchived: state.includeArchived,
    );
    result.when(
      success: (items) => emit(
        state.copyWith(
          status: items.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
          customers: items,
        ),
      ),
      failure: (failure) => emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }

  Future<void> _onArchiveToggled(
    CustomerArchiveToggled event,
    Emitter<CustomerState> emit,
  ) async {
    final result = event.archive
        ? await _archive(event.customerId)
        : await _restore(event.customerId);
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(message: failure.userMessage));
      return;
    }
    await _load(emit);
  }
}
