import 'package:equatable/equatable.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// A customer or supplier as the payments feature sees them.
final class Party extends Equatable {
  /// Creates a party.
  const Party({
    required this.type,
    required this.id,
    required this.name,
    required this.openingBalance,
    required this.isArchived,
  });

  /// Customer or supplier.
  final PartyType type;

  /// Party id.
  final String id;

  /// Party name.
  final String name;

  /// Opening balance entered on the party.
  final Money openingBalance;

  /// Whether the party is archived.
  final bool isArchived;

  @override
  List<Object?> get props => [type, id, name, openingBalance, isArchived];
}

/// Looks up customers and suppliers behind one interface.
final class PartyDirectory {
  /// Creates a directory.
  const PartyDirectory({
    required CustomerRepository customers,
    required SupplierRepository suppliers,
  }) : _customers = customers,
       _suppliers = suppliers;

  final CustomerRepository _customers;
  final SupplierRepository _suppliers;

  /// Loads one party; `NotFoundFailure` if it does not exist.
  Future<Result<Party>> get(PartyType type, String id) async {
    switch (type) {
      case PartyType.customer:
        return (await _customers.getById(id)).map(
          (c) => Party(
            type: type,
            id: c.id,
            name: c.name,
            openingBalance: c.openingBalance,
            isArchived: c.isArchived,
          ),
        );
      case PartyType.supplier:
        return (await _suppliers.getById(id)).map(
          (s) => Party(
            type: type,
            id: s.id,
            name: s.name,
            openingBalance: s.openingBalance,
            isArchived: s.isArchived,
          ),
        );
    }
  }

  /// All parties of a type, archived ones included, ordered by name.
  Future<Result<List<Party>>> all(PartyType type) async {
    switch (type) {
      case PartyType.customer:
        return (await _customers.search(includeArchived: true)).map(
          (list) => [
            for (final c in list)
              Party(
                type: type,
                id: c.id,
                name: c.name,
                openingBalance: c.openingBalance,
                isArchived: c.isArchived,
              ),
          ],
        );
      case PartyType.supplier:
        return (await _suppliers.search(includeArchived: true)).map(
          (list) => [
            for (final s in list)
              Party(
                type: type,
                id: s.id,
                name: s.name,
                openingBalance: s.openingBalance,
                isArchived: s.isArchived,
              ),
          ],
        );
    }
  }
}
