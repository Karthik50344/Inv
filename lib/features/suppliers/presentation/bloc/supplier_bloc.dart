import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/features/suppliers/domain/usecases/archive_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/restore_supplier.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_event.dart';
import 'package:inventrix/features/suppliers/presentation/bloc/supplier_state.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Lists, searches and archives suppliers.
class SupplierBloc extends Bloc<SupplierEvent, SupplierState> {
  /// Creates the bloc.
  SupplierBloc({
    required SupplierRepository repository,
    required ArchiveSupplier archiveSupplier,
    required RestoreSupplier restoreSupplier,
  }) : _repository = repository,
       _archive = archiveSupplier,
       _restore = restoreSupplier,
       super(const SupplierState()) {
    on<SuppliersStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<SuppliersRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<SuppliersSearchChanged>((event, emit) {
      emit(state.copyWith(query: event.query));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<SuppliersArchivedFilterChanged>((event, emit) {
      emit(state.copyWith(includeArchived: event.includeArchived));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<SupplierArchiveToggled>(
      _onArchiveToggled,
      transformer: sequentialTransformer(),
    );
  }

  final SupplierRepository _repository;
  final ArchiveSupplier _archive;
  final RestoreSupplier _restore;

  Future<void> _load(Emitter<SupplierState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _repository.search(
      query: state.query,
      includeArchived: state.includeArchived,
    );
    result.when(
      success: (items) => emit(
        state.copyWith(
          status: items.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
          suppliers: items,
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
    SupplierArchiveToggled event,
    Emitter<SupplierState> emit,
  ) async {
    final result = event.archive
        ? await _archive(event.supplierId)
        : await _restore(event.supplierId);
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(message: failure.userMessage));
      return;
    }
    await _load(emit);
  }
}
