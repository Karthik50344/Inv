import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/purchases/domain/entities/supplier_payable.dart';
import 'package:inventrix/features/purchases/domain/usecases/get_supplier_payable.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/features/suppliers/domain/usecases/archive_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/restore_supplier.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';

/// State of the supplier detail screen.
final class SupplierDetailState extends Equatable {
  /// Creates a state.
  const SupplierDetailState({
    this.status = DetailStatus.loading,
    this.supplier,
    this.payable,
    this.message,
  });

  /// Load status.
  final DetailStatus status;

  /// The supplier.
  final Supplier? supplier;

  /// What the business owes this supplier (`null` when unavailable).
  final SupplierPayable? payable;

  /// One-shot user-facing message.
  final String? message;

  @override
  List<Object?> get props => [status, supplier, payable, message];
}

/// Loads one supplier by id.
class SupplierDetailCubit extends Cubit<SupplierDetailState> {
  /// Creates the cubit.
  SupplierDetailCubit({
    required SupplierRepository repository,
    required ArchiveSupplier archiveSupplier,
    required RestoreSupplier restoreSupplier,
    GetSupplierPayable? getPayable,
  }) : _repository = repository,
       _archive = archiveSupplier,
       _restore = restoreSupplier,
       _getPayable = getPayable,
       super(const SupplierDetailState());

  final SupplierRepository _repository;
  final ArchiveSupplier _archive;
  final RestoreSupplier _restore;
  final GetSupplierPayable? _getPayable;
  String? _id;

  /// Loads supplier [id]; unknown ids end in [DetailStatus.notFound].
  Future<void> load(String id) async {
    _id = id;
    emit(const SupplierDetailState());
    final result = await _repository.getById(id);
    if (isClosed) {
      return;
    }
    final payable = await _getPayable?.call(id);
    if (isClosed) {
      return;
    }
    result.when(
      success: (value) => emit(
        SupplierDetailState(
          status: DetailStatus.loaded,
          supplier: value,
          payable: payable?.valueOrNull,
        ),
      ),
      failure: (failure) => emit(
        SupplierDetailState(
          status: failure is NotFoundFailure
              ? DetailStatus.notFound
              : DetailStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }

  /// Archives the supplier and reloads.
  Future<void> archive() => _toggle(archive: true);

  /// Restores the supplier and reloads.
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
        SupplierDetailState(
          status: state.status,
          supplier: state.supplier,
          payable: state.payable,
          message: failure.userMessage,
        ),
      );
      return;
    }
    await load(id);
  }
}
