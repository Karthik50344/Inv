import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// A customer with contact details and an opening balance.
final class Customer extends Equatable {
  /// Creates a customer.
  const Customer({
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

  /// Builds a customer from validated [fields].
  factory Customer.fromFields({
    required String id,
    required PartyFields fields,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) => Customer(
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

  /// Opening balance (signed: amount the customer owes you; negative is a credit).
  final Money openingBalance;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Last update time (UTC).
  final DateTime updatedAt;

  /// Archive time, if archived.
  final DateTime? archivedAt;

  /// Whether the customer is archived.
  bool get isArchived => archivedAt != null;

  /// Archived copy.
  Customer archived(DateTime at) => _copy(updatedAt: at, archivedAt: at);

  /// Restored (active) copy.
  Customer restored(DateTime at) => _copy(updatedAt: at);

  Customer _copy({required DateTime updatedAt, DateTime? archivedAt}) =>
      Customer(
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
