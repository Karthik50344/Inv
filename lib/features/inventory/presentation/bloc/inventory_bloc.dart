import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_state.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/shared/presentation/bloc_transformers.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// Lists current stock with search and low/out-of-stock filtering.
class InventoryBloc extends Bloc<InventoryEvent, InventoryState> {
  /// Creates the bloc. [initialFilter] lets report screens start filtered.
  InventoryBloc({
    required InventoryRepository inventory,
    required UnitRepository units,
    StockFilter initialFilter = const StockFilter(),
  }) : _inventory = inventory,
       _units = units,
       super(InventoryState(filter: initialFilter)) {
    on<InventoryStarted>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<InventoryRefreshed>(
      (event, emit) => _load(emit),
      transformer: sequentialTransformer(),
    );
    on<InventorySearchChanged>((event, emit) {
      emit(state.copyWith(filter: state.filter.copyWith(query: event.query)));
      return _load(emit);
    }, transformer: sequentialTransformer());
    on<InventoryStatusFilterChanged>((event, emit) {
      emit(state.copyWith(filter: state.filter.copyWith(status: event.status)));
      return _load(emit);
    }, transformer: sequentialTransformer());
  }

  final InventoryRepository _inventory;
  final UnitRepository _units;

  Future<void> _load(Emitter<InventoryState> emit) async {
    emit(state.copyWith(status: ViewStatus.loading));
    final items = await _inventory.listStock(state.filter);
    final valuation = await _inventory.valuation();
    final units = await _units.search(includeArchived: true);
    final failure =
        items.failureOrNull ?? valuation.failureOrNull ?? units.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final list = items.valueOrNull!;
    emit(
      state.copyWith(
        status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        items: list,
        valuation: valuation.valueOrNull,
        units: {for (final unit in units.valueOrNull!) unit.id: unit},
      ),
    );
  }
}
