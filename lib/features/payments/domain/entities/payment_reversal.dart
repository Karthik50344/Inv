import 'package:equatable/equatable.dart';

/// Marks a payment (or refund) as reversed. The payment row is kept; only
/// this record cancels its financial effect.
final class PaymentReversal extends Equatable {
  /// Creates a reversal.
  const PaymentReversal({
    required this.id,
    required this.paymentId,
    required this.reason,
    required this.reversedAt,
  });

  /// Unique id.
  final String id;

  /// The reversed payment.
  final String paymentId;

  /// Why it was reversed.
  final String reason;

  /// When it was reversed (UTC).
  final DateTime reversedAt;

  @override
  List<Object?> get props => [id, paymentId, reason, reversedAt];
}
