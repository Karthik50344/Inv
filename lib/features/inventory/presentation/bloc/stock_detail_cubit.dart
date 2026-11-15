import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_item.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_movement.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';

/// State of the stock detail screen.
final class StockDetailState extends Equatable {
  /// Creates a state.
  const StockDetailState({
    this.status = DetailStatus.loading,
    this.item,
    this.unit,
    this.movements = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.message,
  });

  /// Load status.
  final DetailStatus status;

  /// The product and its balance.
  final StockItem? item;

  /// The product's unit.
  final UnitOfMeasure? unit;

  /// Ledger entries loaded so far, newest first.
  final List<StockMovement> movements;

  /// Whether older entries may exist.
  final bool hasMore;

  /// Whether another page is being loaded.
  final bool loadingMore;

  /// One-shot user-facing message.
  final String? message;

  /// Opening stock may be recorded only while the ledger is empty.
  bool get canRecordOpeningStock =>
      status == DetailStatus.loaded && movements.isEmpty && !hasMore;

  /// Copy with changes; [message] is cleared unless provided.
  StockDetailState copyWith({
    DetailStatus? status,
    StockItem? item,
    UnitOfMeasure? unit,
    List<StockMovement>? movements,
    bool? hasMore,
    bool? loadingMore,
    String? message,
  }) => StockDetailState(
    status: status ?? this.status,
    item: item ?? this.item,
    unit: unit ?? this.unit,
    movements: movements ?? this.movements,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    item,
    unit,
    movements,
    hasMore,
    loadingMore,
    message,
  ];
}

/// Loads one product's stock position and its movement history.
class StockDetailCubit extends Cubit<StockDetailState> {
  /// Creates the cubit.
  StockDetailCubit({
    required InventoryRepository inventory,
    required UnitRepository units,
  }) : _inventory = inventory,
       _units = units,
       super(const StockDetailState());

  /// Entries per history page.
  static const int pageSize = 30;

  final InventoryRepository _inventory;
  final UnitRepository _units;
  String? _productId;

  /// Loads [productId]; unknown ids end in [DetailStatus.notFound].
  Future<void> load(String productId) async {
    _productId = productId;
    emit(const StockDetailState());
    final item = await _inventory.getStockItem(productId);
    final stock = item.valueOrNull;
    if (stock == null) {
      final failure = item.failureOrNull!;
      emit(
        StockDetailState(
          status: failure is NotFoundFailure
              ? DetailStatus.notFound
              : DetailStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final unit = await _units.getById(stock.product.unitId);
    final page = await _inventory.movements(productId, limit: pageSize);
    final failure = unit.failureOrNull ?? page.failureOrNull;
    if (failure != null) {
      emit(
        StockDetailState(
          status: DetailStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    if (isClosed) {
      return;
    }
    final movements = page.valueOrNull!;
    emit(
      StockDetailState(
        status: DetailStatus.loaded,
        item: stock,
        unit: unit.valueOrNull,
        movements: movements,
        hasMore: movements.length == pageSize,
      ),
    );
  }

  /// Loads the next page of history.
  Future<void> loadMore() async {
    final id = _productId;
    if (id == null || state.loadingMore || !state.hasMore) {
      return;
    }
    emit(state.copyWith(loadingMore: true));
    final page = await _inventory.movements(
      id,
      limit: pageSize,
      offset: state.movements.length,
    );
    if (isClosed) {
      return;
    }
    final failure = page.failureOrNull;
    if (failure != null) {
      emit(state.copyWith(loadingMore: false, message: failure.userMessage));
      return;
    }
    final more = page.valueOrNull!;
    emit(
      state.copyWith(
        loadingMore: false,
        movements: [...state.movements, ...more],
        hasMore: more.length == pageSize,
      ),
    );
  }
}
