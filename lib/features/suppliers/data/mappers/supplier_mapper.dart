import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// Row -> entity. The opening balance is interpreted in [currency].
Supplier supplierFromRow(SupplierRow row, CurrencyConfig currency) => Supplier(
  id: row.id,
  name: row.name,
  phone: row.phone,
  email: row.email,
  address: row.address,
  city: row.city,
  state: row.state,
  postalCode: row.postalCode,
  taxId: row.taxId,
  notes: row.notes,
  openingBalance: currency.fromMinor(row.openingBalanceMinor),
  createdAt: fromEpochMs(row.createdAt),
  updatedAt: fromEpochMs(row.updatedAt),
  archivedAt: fromEpochMsOrNull(row.archivedAt),
);

/// Entity -> insert/update companion.
SuppliersCompanion supplierToCompanion(Supplier supplier) => SuppliersCompanion(
  id: Value(supplier.id),
  name: Value(supplier.name),
  phone: Value(supplier.phone),
  email: Value(supplier.email),
  address: Value(supplier.address),
  city: Value(supplier.city),
  state: Value(supplier.state),
  postalCode: Value(supplier.postalCode),
  taxId: Value(supplier.taxId),
  notes: Value(supplier.notes),
  openingBalanceMinor: Value(supplier.openingBalance.minorUnits),
  archivedAt: Value(toEpochMsOrNull(supplier.archivedAt)),
  createdAt: Value(toEpochMs(supplier.createdAt)),
  updatedAt: Value(toEpochMs(supplier.updatedAt)),
);
