import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Criteria for listing sale invoices.
final class SalesFilter extends Equatable {
  /// Creates a filter.
  const SalesFilter({this.query = '', this.status, this.customerId});

  /// Matches number, customer name or customer reference (contains,
  /// case-insensitive).
  final String query;

  /// Restrict to one status.
  final DocumentStatus? status;

  /// Restrict to one customer.
  final String? customerId;

  /// Copy with changes; use [clearStatus] to remove the status filter.
  SalesFilter copyWith({
    String? query,
    DocumentStatus? status,
    bool clearStatus = false,
    String? customerId,
  }) => SalesFilter(
    query: query ?? this.query,
    status: clearStatus ? null : (status ?? this.status),
    customerId: customerId ?? this.customerId,
  );

  @override
  List<Object?> get props => [query, status, customerId];
}
