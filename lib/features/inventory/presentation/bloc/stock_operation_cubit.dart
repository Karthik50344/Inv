import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_item.dart';
import 'package:inventrix/features/inventory/domain/repositories/inventory_repository.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/record_opening_stock.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/features/products/domain/repositories/unit_repository.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// A manual stock operation.
enum StockOperation {
  opening,
  stockIn,
  stockOut;

  /// Screen title.
  String get title => switch (this) {
    StockOperation.opening => 'Opening stock',
    StockOperation.stockIn => 'Stock in',
    StockOperation.stockOut => 'Stock out',
  };
}

/// State of the stock operation form.
final class StockOperationState extends Equatable {
  /// Creates a state.
  const StockOperationState({
    this.loadStatus = FormLoadStatus.loading,
    this.submitStatus = SubmitStatus.idle,
    this.item,
    this.unit,
    this.currency,
    this.blockedReason,
    this.fieldErrors = const {},
    this.message,
  });

  /// Load status.
  final FormLoadStatus loadStatus;

  /// Submission status.
  final SubmitStatus submitStatus;

  /// The product and its balance.
  final StockItem? item;

  /// The product's unit (defines precision).
  final UnitOfMeasure? unit;

  /// Active currency.
  final CurrencyConfig? currency;

  /// Why the operation cannot be performed at all (e.g. opening stock
  /// already recorded).
  final String? blockedReason;

  /// Per-field validation messages from the last submit.
  final Map<String, String> fieldErrors;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [fieldErrors] and [message] reset unless provided.
  StockOperationState copyWith({
    FormLoadStatus? loadStatus,
    SubmitStatus? submitStatus,
    StockItem? item,
    UnitOfMeasure? unit,
    CurrencyConfig? currency,
    String? blockedReason,
    Map<String, String>? fieldErrors,
    String? message,
  }) => StockOperationState(
    loadStatus: loadStatus ?? this.loadStatus,
    submitStatus: submitStatus ?? this.submitStatus,
    item: item ?? this.item,
    unit: unit ?? this.unit,
    currency: currency ?? this.currency,
    blockedReason: blockedReason ?? this.blockedReason,
    fieldErrors: fieldErrors ?? const {},
    message: message,
  );

  @override
  List<Object?> get props => [
    loadStatus,
    submitStatus,
    item,
    unit,
    currency,
    blockedReason,
    fieldErrors,
    message,
  ];
}

/// Drives the opening stock / stock in / stock out form.
class StockOperationCubit extends Cubit<StockOperationState> {
  /// Creates the cubit.
  StockOperationCubit({
    required InventoryRepository inventory,
    required UnitRepository units,
    required SettingsRepository settings,
    required RecordOpeningStock recordOpeningStock,
    required AdjustStock adjustStock,
  }) : _inventory = inventory,
       _units = units,
       _settings = settings,
       _opening = recordOpeningStock,
       _adjust = adjustStock,
       super(const StockOperationState());

  final InventoryRepository _inventory;
  final UnitRepository _units;
  final SettingsRepository _settings;
  final RecordOpeningStock _opening;
  final AdjustStock _adjust;
  String? _productId;
  StockOperation? _operation;

  /// Loads the product for [operation].
  Future<void> load(String productId, StockOperation operation) async {
    _productId = productId;
    _operation = operation;
    emit(const StockOperationState());
    final item = await _inventory.getStockItem(productId);
    final stock = item.valueOrNull;
    if (stock == null) {
      final failure = item.failureOrNull!;
      emit(
        state.copyWith(
          loadStatus: failure is NotFoundFailure
              ? FormLoadStatus.notFound
              : FormLoadStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final unit = await _units.getById(stock.product.unitId);
    final currency = await _settings.getCurrencyConfig();
    final hasMovements = operation == StockOperation.opening
        ? await _inventory.hasMovements(productId)
        : null;
    final failure =
        unit.failureOrNull ??
        currency.failureOrNull ??
        hasMovements?.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          loadStatus: FormLoadStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    String? blocked;
    if (stock.product.isArchived) {
      blocked = 'This product is archived. Restore it to change its stock.';
    } else if (hasMovements?.valueOrNull ?? false) {
      blocked =
          'Opening stock was already recorded or stock has moved. '
          'Use Stock in / Stock out instead.';
    } else if (operation == StockOperation.stockOut &&
        stock.balance.quantityOnHand.isZero) {
      blocked = 'There is no stock to remove.';
    }
    emit(
      state.copyWith(
        loadStatus: FormLoadStatus.ready,
        item: stock,
        unit: unit.valueOrNull,
        currency: currency.valueOrNull,
        blockedReason: blocked,
      ),
    );
  }

  /// Validates and records the operation.
  Future<void> submit({
    required String quantity,
    String unitCost = '',
    String reason = '',
  }) async {
    final productId = _productId;
    final operation = _operation;
    if (productId == null ||
        operation == null ||
        state.submitStatus == SubmitStatus.submitting) {
      return;
    }
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final result = switch (operation) {
      StockOperation.opening => await _opening(
        productId: productId,
        quantity: quantity,
        unitCost: unitCost,
      ),
      StockOperation.stockIn => await _adjust(
        productId: productId,
        direction: StockAdjustmentDirection.stockIn,
        quantity: quantity,
        unitCost: unitCost,
        reason: reason,
      ),
      StockOperation.stockOut => await _adjust(
        productId: productId,
        direction: StockAdjustmentDirection.stockOut,
        quantity: quantity,
        reason: reason,
      ),
    };
    if (isClosed) {
      return;
    }
    result.when(
      success: (_) => emit(state.copyWith(submitStatus: SubmitStatus.success)),
      failure: (failure) => emit(
        failure is ValidationFailure
            ? state.copyWith(
                submitStatus: SubmitStatus.validationError,
                fieldErrors: failure.fieldErrors,
                message: failure.fieldErrors.isEmpty ? failure.message : null,
              )
            : state.copyWith(
                submitStatus: SubmitStatus.failure,
                message: failure.userMessage,
              ),
      ),
    );
  }
}
