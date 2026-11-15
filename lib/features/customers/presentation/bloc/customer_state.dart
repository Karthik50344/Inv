import 'package:equatable/equatable.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the customer list.
final class CustomerState extends Equatable {
  /// Creates a state.
  const CustomerState({
    this.status = ViewStatus.initial,
    this.customers = const [],
    this.query = '',
    this.includeArchived = false,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded customers.
  final List<Customer> customers;

  /// Current search text.
  final String query;

  /// Whether archived customers are shown.
  final bool includeArchived;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  CustomerState copyWith({
    ViewStatus? status,
    List<Customer>? customers,
    String? query,
    bool? includeArchived,
    String? message,
  }) => CustomerState(
    status: status ?? this.status,
    customers: customers ?? this.customers,
    query: query ?? this.query,
    includeArchived: includeArchived ?? this.includeArchived,
    message: message,
  );

  @override
  List<Object?> get props => [
    status,
    customers,
    query,
    includeArchived,
    message,
  ];
}
