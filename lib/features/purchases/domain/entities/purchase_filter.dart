import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Criteria for listing purchase invoices.
final class PurchaseFilter extends Equatable {
  /// Creates a filter.
  const PurchaseFilter({this.query = '', this.status, this.supplierId});

  /// Matches number, supplier name or supplier reference (contains,
  /// case-insensitive).
  final String query;

  /// Restrict to one status.
  final DocumentStatus? status;

  /// Restrict to one supplier.
  final String? supplierId;

  /// Copy with changes; use [clearStatus] to remove the status filter.
  PurchaseFilter copyWith({
    String? query,
    DocumentStatus? status,
    bool clearStatus = false,
    String? supplierId,
  }) => PurchaseFilter(
    query: query ?? this.query,
    status: clearStatus ? null : (status ?? this.status),
    supplierId: supplierId ?? this.supplierId,
  );

  @override
  List<Object?> get props => [query, status, supplierId];
}
