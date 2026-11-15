import 'package:equatable/equatable.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';

/// What a customer owes us or what we owe a supplier.
///
/// `balance = opening + invoiced - returns - payments + refunds
/// + returnRefunds`. A positive balance is
/// money still to be collected (customer) or paid (supplier); a negative one
/// is an advance or credit.
final class PartyBalance extends Equatable {
  /// Creates a balance.
  const PartyBalance({
    required this.partyType,
    required this.partyId,
    required this.partyName,
    required this.opening,
    required this.invoiced,
    required this.payments,
    required this.refunds,
    required this.returns,
    required this.returnRefunds,
  });

  /// Customer or supplier.
  final PartyType partyType;

  /// Party id.
  final String partyId;

  /// Party name.
  final String partyName;

  /// Opening balance entered on the party.
  final Money opening;

  /// Total of posted invoices.
  final Money invoiced;

  /// Active payments (received from a customer / paid to a supplier).
  final Money payments;

  /// Active refunds (paid to a customer / received from a supplier).
  final Money refunds;

  /// Value of posted returns (credit notes), including tax.
  final Money returns;

  /// Cash handed back through returns (paid to a customer / received from
  /// a supplier).
  final Money returnRefunds;

  /// The amount still outstanding (negative: credit).
  Money get balance =>
      opening + invoiced - returns - payments + refunds + returnRefunds;

  /// Whether nothing is outstanding.
  bool get isSettled => balance.isZero;

  /// Whether the party has credit with us (or we with them).
  bool get hasCredit => balance.isNegative;

  @override
  List<Object?> get props => [
    partyType,
    partyId,
    partyName,
    opening,
    invoiced,
    payments,
    refunds,
    returns,
    returnRefunds,
  ];
}
