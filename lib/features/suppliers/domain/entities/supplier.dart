import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// A supplier with contact details and an opening balance.
final class Supplier extends Equatable {
  /// Creates a supplier.
  const Supplier({
    required this.id,
    required this.name,
    required this.openingBalance,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.taxId,
    this.notes,
    this.archivedAt,
  });

  /// Builds a supplier from validated [fields].
  factory Supplier.fromFields({
    required String id,
    required PartyFields fields,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) => Supplier(
    id: id,
    name: fields.name,
    phone: fields.phone,
    email: fields.email,
    address: fields.address,
    city: fields.city,
    state: fields.state,
    postalCode: fields.postalCode,
    taxId: fields.taxId,
    notes: fields.notes,
    openingBalance: fields.openingBalance,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );

  /// Unique id.
  final String id;

  /// Name.
  final String name;

  /// Phone number.
  final String? phone;

  /// E-mail address.
  final String? email;

  /// Street address.
  final String? address;

  /// City.
  final String? city;

  /// State/region.
  final String? state;

  /// Postal code.
  final String? postalCode;

  /// Tax identification number.
  final String? taxId;

  /// Notes.
  final String? notes;

  /// Opening balance (signed: amount you owe the supplier; negative is a credit).
  final Money openingBalance;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Last update time (UTC).
  final DateTime updatedAt;

  /// Archive time, if archived.
  final DateTime? archivedAt;

  /// Whether the supplier is archived.
  bool get isArchived => archivedAt != null;

  /// Archived copy.
  Supplier archived(DateTime at) => _copy(updatedAt: at, archivedAt: at);

  /// Restored (active) copy.
  Supplier restored(DateTime at) => _copy(updatedAt: at);

  Supplier _copy({required DateTime updatedAt, DateTime? archivedAt}) =>
      Supplier(
        id: id,
        name: name,
        phone: phone,
        email: email,
        address: address,
        city: city,
        state: state,
        postalCode: postalCode,
        taxId: taxId,
        notes: notes,
        openingBalance: openingBalance,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
      );

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    email,
    address,
    city,
    state,
    postalCode,
    taxId,
    notes,
    openingBalance,
    createdAt,
    updatedAt,
    archivedAt,
  ];
}
