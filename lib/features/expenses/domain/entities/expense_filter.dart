import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Criteria for listing expenses.
final class ExpenseFilter extends Equatable {
  /// Creates a filter.
  const ExpenseFilter({
    this.query = '',
    this.status,
    this.categoryId,
    this.from,
    this.to,
  });

  /// Matches number, description, payee, category or reference (contains,
  /// case-insensitive).
  final String query;

  /// Restrict to one status.
  final DocumentStatus? status;

  /// Restrict to one category.
  final String? categoryId;

  /// First day to include (date only).
  final DateTime? from;

  /// Last day to include (date only).
  final DateTime? to;

  /// Whether any criterion is set.
  bool get isActive =>
      query.trim().isNotEmpty ||
      status != null ||
      categoryId != null ||
      from != null ||
      to != null;

  /// Copy with changes. The `clear*` flags remove a criterion.
  ExpenseFilter copyWith({
    String? query,
    DocumentStatus? status,
    bool clearStatus = false,
    String? categoryId,
    bool clearCategory = false,
    DateTime? from,
    DateTime? to,
    bool clearRange = false,
  }) => ExpenseFilter(
    query: query ?? this.query,
    status: clearStatus ? null : (status ?? this.status),
    categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
    from: clearRange ? null : (from ?? this.from),
    to: clearRange ? null : (to ?? this.to),
  );

  @override
  List<Object?> get props => [query, status, categoryId, from, to];
}
