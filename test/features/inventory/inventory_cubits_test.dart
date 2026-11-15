import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_balance.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_filter.dart';
import 'package:inventrix/features/inventory/domain/entities/stock_status.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:inventrix/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:inventrix/features/inventory/presentation/bloc/reconciliation_cubit.dart';
import 'package:inventrix/features/inventory/presentation/bloc/stock_detail_cubit.dart';
import 'package:inventrix/features/inventory/presentation/bloc/stock_operation_cubit.dart';
import 'package:inventrix/features/products/domain/usecases/archive_product.dart';
import 'package:inventrix/features/products/presentation/bloc/product_detail_cubit.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

import '../../support/inventory_fixture.dart';

void main() {
  late InventoryFixture f;

  setUp(() => f = InventoryFixture());

  InventoryBloc buildBloc([StockFilter filter = const StockFilter()]) =>
      InventoryBloc(
        inventory: f.inventory,
        units: f.units,
        initialFilter: filter,
      );

  StockDetailCubit buildDetail() =>
      StockDetailCubit(inventory: f.inventory, units: f.units);

  StockOperationCubit buildOperation() => StockOperationCubit(
    inventory: f.inventory,
    units: f.units,
    settings: f.settings,
    recordOpeningStock: f.openingStock,
    adjustStock: f.adjustStock,
  );

  Future<String> stocked(
    String name,
    String sku,
    String qty, {
    String reorder = '',
  }) async {
    final p = await f.addProduct(name: name, sku: sku, reorder: reorder);
    if (qty != '0') {
      await f.openingStock(productId: p.id, quantity: qty, unitCost: '10');
    }
    return p.id;
  }

  group('InventoryBloc', () {
    test('starts in the initial state', () {
      expect(buildBloc().state.status, ViewStatus.initial);
    });

    test('empty when there are no products', () async {
      final bloc = buildBloc()..add(const InventoryStarted());
      await bloc.stream.firstWhere((s) => s.status == ViewStatus.empty);
      expect(bloc.state.valuation?.productsInStock, 0);
      await bloc.close();
    });

    test('loads stock with valuation and units', () async {
      await stocked('Hammer', 'H-1', '10');
      await stocked('Saw', 'S-1', '5');
      final bloc = buildBloc()..add(const InventoryStarted());
      await bloc.stream.firstWhere((s) => s.status == ViewStatus.loaded);
      expect(bloc.state.items.length, 2);
      expect(bloc.state.valuation?.totalValue.minorUnits, 15000);
      expect(bloc.state.valuation?.productsInStock, 2);
      expect(bloc.state.units['pcs']?.symbol, 'pcs');
      await bloc.close();
    });

    test('low and out-of-stock filters and counts', () async {
      await stocked('Plenty', 'P-1', '50', reorder: '10');
      await stocked('Running low', 'L-1', '8', reorder: '10');
      await stocked('Exactly at level', 'E-1', '10', reorder: '10');
      await stocked('Empty', 'O-1', '0', reorder: '5');
      await stocked('No reorder set', 'N-1', '1');
      final bloc = buildBloc()..add(const InventoryStarted());
      await bloc.stream.firstWhere((s) => s.status == ViewStatus.loaded);
      expect(bloc.state.valuation?.lowStockCount, 2);
      expect(bloc.state.valuation?.outOfStockCount, 1);

      bloc.add(const InventoryStatusFilterChanged(StockStatusFilter.low));
      await bloc.stream.firstWhere(
        (s) =>
            s.filter.status == StockStatusFilter.low &&
            s.status == ViewStatus.loaded &&
            s.items.length == 2,
      );
      expect(bloc.state.items.map((i) => i.product.name).toList(), [
        'Exactly at level',
        'Running low',
      ]);

      bloc.add(const InventoryStatusFilterChanged(StockStatusFilter.out));
      await bloc.stream.firstWhere(
        (s) =>
            s.filter.status == StockStatusFilter.out &&
            s.status == ViewStatus.loaded &&
            s.items.length == 1,
      );
      expect(bloc.state.items.single.product.name, 'Empty');
      await bloc.close();
    });

    test('a report bloc can start with a preset filter', () async {
      await stocked('Plenty', 'P-1', '50', reorder: '10');
      await stocked('Low', 'L-1', '2', reorder: '10');
      final bloc = buildBloc(
        const StockFilter(status: StockStatusFilter.lowOrOut),
      )..add(const InventoryStarted());
      await bloc.stream.firstWhere((s) => s.status == ViewStatus.loaded);
      expect(bloc.state.items.single.product.name, 'Low');
      await bloc.close();
    });

    test('search narrows the list', () async {
      await stocked('Hammer', 'H-1', '1');
      await stocked('Saw', 'S-1', '1');
      final bloc = buildBloc()..add(const InventorySearchChanged('saw'));
      await bloc.stream.firstWhere((s) => s.status == ViewStatus.loaded);
      expect(bloc.state.items.single.product.name, 'Saw');
      await bloc.close();
    });

    test(
      'archived products are excluded from stock lists and counts',
      () async {
        final id = await stocked('Old', 'O-1', '5', reorder: '10');
        await ArchiveProduct(products: f.products, clock: f.clock)(id);
        final bloc = buildBloc()..add(const InventoryStarted());
        await bloc.stream.firstWhere((s) => s.status == ViewStatus.empty);
        // Value of archived stock still counts toward the total.
        expect(bloc.state.valuation?.totalValue.minorUnits, 5000);
        expect(bloc.state.valuation?.lowStockCount, 0);
        await bloc.close();
      },
    );

    test('repository failures end in the failure state', () async {
      f.products.searchFailure = const DatabaseFailure('offline');
      final bloc = buildBloc()..add(const InventoryStarted());
      final s = await bloc.stream.firstWhere(
        (s) => s.status == ViewStatus.failure,
      );
      expect(s.message, 'offline');
      await bloc.close();
    });
  });

  group('StockDetailCubit', () {
    test('loads balance, unit and history (newest first)', () async {
      final id = await stocked('Hammer', 'H-1', '10');
      await f.adjustStock(
        productId: id,
        direction: StockAdjustmentDirection.stockOut,
        quantity: '4',
        reason: 'Count',
      );
      final cubit = buildDetail();
      await cubit.load(id);
      expect(cubit.state.status, DetailStatus.loaded);
      expect(cubit.state.item?.balance.quantityOnHand.milli, 6000);
      expect(cubit.state.unit?.symbol, 'pcs');
      expect(cubit.state.movements.length, 2);
      expect(cubit.state.movements.first.quantityDelta.milli, -4000);
      expect(cubit.state.canRecordOpeningStock, isFalse);
    });

    test('opening stock is offered only while the ledger is empty', () async {
      final p = await f.addProduct();
      final cubit = buildDetail();
      await cubit.load(p.id);
      expect(cubit.state.canRecordOpeningStock, isTrue);
    });

    test('unknown ids end in notFound', () async {
      final cubit = buildDetail();
      await cubit.load('ghost');
      expect(cubit.state.status, DetailStatus.notFound);
    });

    test('history is paged', () async {
      final id = await stocked('Hammer', 'H-1', '100');
      for (var i = 0; i < StockDetailCubit.pageSize + 4; i++) {
        await f.adjustStock(
          productId: id,
          direction: StockAdjustmentDirection.stockOut,
          quantity: '1',
          reason: 'step $i',
        );
      }
      final cubit = buildDetail();
      await cubit.load(id);
      expect(cubit.state.movements.length, StockDetailCubit.pageSize);
      expect(cubit.state.hasMore, isTrue);
      await cubit.loadMore();
      expect(cubit.state.movements.length, StockDetailCubit.pageSize + 5);
      expect(cubit.state.hasMore, isFalse);
    });
  });

  group('StockOperationCubit', () {
    test('opening stock form is blocked once the ledger has entries', () async {
      final id = await stocked('Hammer', 'H-1', '3');
      final cubit = buildOperation();
      await cubit.load(id, StockOperation.opening);
      expect(cubit.state.loadStatus, FormLoadStatus.ready);
      expect(cubit.state.blockedReason, isNotNull);
    });

    test('stock out is blocked with no stock', () async {
      final p = await f.addProduct();
      final cubit = buildOperation();
      await cubit.load(p.id, StockOperation.stockOut);
      expect(cubit.state.blockedReason, 'There is no stock to remove.');
    });

    test('unknown product ends in notFound', () async {
      final cubit = buildOperation();
      await cubit.load('ghost', StockOperation.stockIn);
      expect(cubit.state.loadStatus, FormLoadStatus.notFound);
    });

    test('invalid submit exposes field errors and records nothing', () async {
      final id = await stocked('Hammer', 'H-1', '3');
      final cubit = buildOperation();
      await cubit.load(id, StockOperation.stockOut);
      await cubit.submit(quantity: '', reason: '');
      expect(cubit.state.submitStatus, SubmitStatus.validationError);
      expect(cubit.state.fieldErrors.containsKey('quantity'), isTrue);
      expect(cubit.state.fieldErrors.containsKey('reason'), isTrue);
      expect(f.inventory.ledger.length, 1);
    });

    test('insufficient stock is reported without changing anything', () async {
      final id = await stocked('Hammer', 'H-1', '3');
      final cubit = buildOperation();
      await cubit.load(id, StockOperation.stockOut);
      await cubit.submit(quantity: '9', reason: 'Oops');
      expect(cubit.state.submitStatus, SubmitStatus.failure);
      expect(cubit.state.message, contains('Only 3'));
      expect(f.inventory.balances[id]!.quantityOnHand.milli, 3000);
    });

    test('each operation succeeds and updates the ledger', () async {
      final p = await f.addProduct();
      final opening = buildOperation();
      await opening.load(p.id, StockOperation.opening);
      await opening.submit(quantity: '10', unitCost: '5');
      expect(opening.state.submitStatus, SubmitStatus.success);

      final stockIn = buildOperation();
      await stockIn.load(p.id, StockOperation.stockIn);
      await stockIn.submit(quantity: '5', unitCost: '8', reason: 'Delivery');
      expect(stockIn.state.submitStatus, SubmitStatus.success);

      final stockOut = buildOperation();
      await stockOut.load(p.id, StockOperation.stockOut);
      await stockOut.submit(quantity: '3', reason: 'Damaged');
      expect(stockOut.state.submitStatus, SubmitStatus.success);

      expect(f.inventory.ledger.length, 3);
      expect(f.inventory.balances[p.id]!.quantityOnHand.milli, 12000);
    });

    test('archived products cannot receive stock operations', () async {
      final p = await f.addProduct();
      await ArchiveProduct(products: f.products, clock: f.clock)(p.id);
      final cubit = buildOperation();
      await cubit.load(p.id, StockOperation.stockIn);
      expect(cubit.state.blockedReason, contains('archived'));
    });
  });

  group('ReconciliationCubit', () {
    ReconciliationCubit build() =>
        ReconciliationCubit(reconcile: f.reconcile, repair: f.repair);

    test('reports a consistent database', () async {
      await stocked('Hammer', 'H-1', '5');
      final cubit = build();
      await cubit.run();
      expect(cubit.state.status, ReconciliationStatus.done);
      expect(cubit.state.report?.isConsistent, isTrue);
    });

    test('detects a mismatch and repairs it', () async {
      final id = await stocked('Hammer', 'H-1', '5');
      f.inventory.balances[id] = StockBalance(
        productId: id,
        quantityOnHand: const Quantity.fromMilli(1),
        inventoryValue: Money.fromMinor(
          1,
          currencyCode: 'INR',
          decimalPlaces: 2,
        ),
      );
      final cubit = build();
      await cubit.run();
      expect(cubit.state.report?.mismatches.length, 1);
      await cubit.repair();
      expect(cubit.state.status, ReconciliationStatus.done);
      expect(cubit.state.repairedCount, 1);
      expect(cubit.state.report?.isConsistent, isTrue);
    });

    test('a failed repair is reported and keeps the report', () async {
      final id = await stocked('Hammer', 'H-1', '5');
      f.inventory.balances[id] = StockBalance(
        productId: id,
        quantityOnHand: const Quantity.fromMilli(1),
        inventoryValue: Money.fromMinor(
          1,
          currencyCode: 'INR',
          decimalPlaces: 2,
        ),
      );
      f.audit.recordFailure = const DatabaseFailure('audit unavailable');
      final cubit = build();
      await cubit.run();
      await cubit.repair();
      expect(cubit.state.status, ReconciliationStatus.failure);
      expect(cubit.state.report?.mismatches.length, 1);
    });
  });
}
