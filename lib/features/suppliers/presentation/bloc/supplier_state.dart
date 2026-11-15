import 'package:equatable/equatable.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the supplier list.
final class SupplierState extends Equatable {
  /// Creates a state.
  const SupplierState({
    this.status = ViewStatus.initial,
    this.suppliers = const [],
    this.query = '',
    this.includeArchived = false,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded suppliers.
  final List<Supplier> suppliers;

  /// Current search text.
  final String query;

  /// Whether archived suppliers are shown.
  final bool includeArchived;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  SupplierState copyWith({
    ViewStatus? status,
    List<Supplier>? suppliers,
    String? query,
    bool? includeArchived,
    String? message,
  }) => SupplierState(
    status: status ?? this.status,
    suppliers: suppliers ?? this.suppliers,
    query: query ?? this.query,
    includeArchived: includeArchived ?? this.includeArchived,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    suppliers,
    query,
    includeArchived,
    message,
  ];
}
