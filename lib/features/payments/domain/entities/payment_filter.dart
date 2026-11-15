import 'package:equatable/equatable.dart';
import 'package:inventrix/features/payments/domain/entities/party_type.dart';
import 'package:inventrix/features/payments/domain/entities/payment_kind.dart';

/// Criteria for the payment history.
final class PaymentFilter extends Equatable {
  /// Creates a filter.
  const PaymentFilter({
    this.query = '',
    this.partyType,
    this.partyId,
    this.kind,
    this.invoiceId,
    this.includeReversed = true,
  });

  /// Matches the number, party name, reference or method.
  final String query;

  /// Restrict to customers or suppliers.
  final PartyType? partyType;

  /// Restrict to one customer or supplier.
  final String? partyId;

  /// Restrict to payments or refunds.
  final PaymentKind? kind;

  /// Restrict to records allocated to one invoice.
  final String? invoiceId;

  /// Whether reversed payments are listed.
  final bool includeReversed;

  /// A copy with changes; the `clear*` flags remove a restriction.
  PaymentFilter copyWith({
    String? query,
    PartyType? partyType,
    PaymentKind? kind,
    bool? includeReversed,
    bool clearPartyType = false,
    bool clearKind = false,
  }) => PaymentFilter(
    query: query ?? this.query,
    partyType: clearPartyType ? null : (partyType ?? this.partyType),
    partyId: partyId,
    kind: clearKind ? null : (kind ?? this.kind),
    invoiceId: invoiceId,
    includeReversed: includeReversed ?? this.includeReversed,
  );

  @override
  List<Object?> get props => [
    query,
    partyType,
    partyId,
    kind,
    invoiceId,
    includeReversed,
  ];
}
