import 'package:drift/drift.dart';
import 'package:inventrix/core/database/app_database.dart';
import 'package:inventrix/core/utils/epoch.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';

/// Row -> entity. The opening balance is interpreted in [currency].
Customer customerFromRow(CustomerRow row, CurrencyConfig currency) => Customer(
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
CustomersCompanion customerToCompanion(Customer customer) => CustomersCompanion(
  id: Value(customer.id),
  name: Value(customer.name),
  phone: Value(customer.phone),
  email: Value(customer.email),
  address: Value(customer.address),
  city: Value(customer.city),
  state: Value(customer.state),
  postalCode: Value(customer.postalCode),
  taxId: Value(customer.taxId),
  notes: Value(customer.notes),
  openingBalanceMinor: Value(customer.openingBalance.minorUnits),
  archivedAt: Value(toEpochMsOrNull(customer.archivedAt)),
  createdAt: Value(toEpochMs(customer.createdAt)),
  updatedAt: Value(toEpochMs(customer.updatedAt)),
);
