import 'package:equatable/equatable.dart';

/// A way of paying (cash, bank transfer, ...). Methods are archived, never
/// deleted, because payments keep a snapshot of the name anyway.
final class PaymentMethod extends Equatable {
  /// Creates a payment method.
  const PaymentMethod({
    required this.id,
    required this.name,
    required this.createdAt,
    this.archivedAt,
  });

  /// Unique id.
  final String id;

  /// Display name, unique among active methods (case-insensitive).
  final String name;

  /// When the method was created (UTC).
  final DateTime createdAt;

  /// When the method was archived (UTC), if it was.
  final DateTime? archivedAt;

  /// Whether the method can no longer be chosen for new payments.
  bool get isArchived => archivedAt != null;

  @override
  List<Object?> get props => [id, name, createdAt, archivedAt];
}
