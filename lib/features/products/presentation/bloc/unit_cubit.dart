import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/domain/usecases/add_common_units.dart';
import 'package:inventrix/features/products/domain/usecases/archive_unit.dart';
import 'package:inventrix/features/products/domain/usecases/create_unit.dart';
import 'package:inventrix/features/products/domain/usecases/restore_unit.dart';
import 'package:inventrix/features/products/domain/usecases/update_unit.dart';
import 'package:inventrix/features/products/presentation/bloc/unit_state.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Lists, searches and manages units of measurement.
class UnitCubit extends Cubit<UnitState> {
  /// Creates the cubit.
  UnitCubit({
    required UnitRepository repository,
    required CreateUnit createUnit,
    required UpdateUnit updateUnit,
    required ArchiveUnit archiveUnit,
    required RestoreUnit restoreUnit,
    required AddCommonUnits addCommonUnits,
  }) : _repository = repository,
       _create = createUnit,
       _update = updateUnit,
       _archive = archiveUnit,
       _restore = restoreUnit,
       _addCommon = addCommonUnits,
       super(const UnitState());

  final UnitRepository _repository;
  final CreateUnit _create;
  final UpdateUnit _update;
  final ArchiveUnit _archive;
  final RestoreUnit _restore;
  final AddCommonUnits _addCommon;

  /// Loads units for the current query/filter.
  Future<void> load() async {
    emit(state.copyWith(status: ViewStatus.loading));
    final result = await _repository.search(
      query: state.query,
      includeArchived: state.includeArchived,
    );
    if (isClosed) {
      return;
    }
    result.when(
      success: (units) => emit(
        state.copyWith(
          status: units.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
          units: units,
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

  /// Applies a search query and reloads.
  Future<void> search(String query) {
    emit(state.copyWith(query: query));
    return load();
  }

  /// Shows or hides archived units and reloads.
  Future<void> setIncludeArchived({required bool value}) {
    emit(state.copyWith(includeArchived: value));
    return load();
  }

  /// Creates a unit.
  Future<Result<UnitOfMeasure>> create({
    required String name,
    required String symbol,
    required int decimalPlaces,
  }) async {
    final result = await _create(
      name: name,
      symbol: symbol,
      decimalPlaces: decimalPlaces,
    );
    if (result.isSuccess) {
      await load();
    }
    return result;
  }

  /// Updates a unit.
  Future<Result<UnitOfMeasure>> update({
    required String id,
    required String name,
    required String symbol,
    required int decimalPlaces,
  }) async {
    final result = await _update(
      id: id,
      name: name,
      symbol: symbol,
      decimalPlaces: decimalPlaces,
    );
    if (result.isSuccess) {
      await load();
    }
    return result;
  }

  /// Archives a unit; failures are reported via [UnitState.message].
  Future<void> archive(String id) => _run(_archive(id));

  /// Restores a unit; failures are reported via [UnitState.message].
  Future<void> restore(String id) => _run(_restore(id));

  /// Adds the common units that are missing.
  Future<void> addCommonUnits() async {
    final result = await _addCommon();
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(message: failure.userMessage));
      return;
    }
    await load();
  }

  Future<void> _run(Future<Result<void>> action) async {
    final result = await action;
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(message: failure.userMessage));
      return;
    }
    await load();
  }
}
