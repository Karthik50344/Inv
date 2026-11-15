import 'package:inventrix/features/inventory/domain/services/stock_operation_support.dart';
import 'package:inventrix/features/inventory/domain/usecases/adjust_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/reconcile_inventory.dart';
import 'package:inventrix/features/inventory/domain/usecases/record_opening_stock.dart';
import 'package:inventrix/features/inventory/domain/usecases/repair_inventory_balances.dart';
import 'package:inventrix/features/products/domain/entities/product.dart';
import 'package:inventrix/features/products/domain/entities/product_draft.dart';
import 'package:inventrix/features/products/domain/usecases/create_product.dart';

import 'domain_fixture.dart';
import 'inventory_fakes.dart';

/// Wires the inventory use cases on top of the fake repositories.
class InventoryFixture extends DomainFixture {
  InventoryFixture() {
    inventory = FakeInventoryRepository(products, settings.config, clock);
    audit = FakeAuditLogRepository();
    transactions = FakeTransactionRunner([inventory, audit]);
    support = StockOperationSupport(
      products: products,
      units: units,
      settings: settings,
    );
    openingStock = RecordOpeningStock(
      support: support,
      inventory: inventory,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    adjustStock = AdjustStock(
      support: support,
      inventory: inventory,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    reconcile = ReconcileInventory(inventory: inventory);
    repair = RepairInventoryBalances(
      reconcile: reconcile,
      inventory: inventory,
      audit: audit,
      transactions: transactions,
      ids: ids,
      clock: clock,
    );
    seedUnit(this, id: 'pcs', symbol: 'pcs');
    seedUnit(this, id: 'kg', symbol: 'kg', decimals: 3);
  }

  late final FakeInventoryRepository inventory;
  late final FakeAuditLogRepository audit;
  late final FakeTransactionRunner transactions;
  late final StockOperationSupport support;
  late final RecordOpeningStock openingStock;
  late final AdjustStock adjustStock;
  late final ReconcileInventory reconcile;
  late final RepairInventoryBalances repair;

  /// Creates a product through the real use case.
  Future<Product> addProduct({
    String name = 'Hammer',
    String sku = '',
    String unitId = 'pcs',
    String purchase = '10',
    String selling = '',
    String reorder = '',
  }) async {
    final result =
        await CreateProduct(
          validator: validator,
          products: products,
          ids: ids,
          clock: clock,
        )(
          ProductDraft(
            name: name,
            sku: sku,
            unitId: unitId,
            purchasePrice: purchase,
            sellingPrice: selling,
            reorderLevel: reorder,
          ),
        );
    return result.valueOrNull!;
  }
}
