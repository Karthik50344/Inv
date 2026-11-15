import 'package:equatable/equatable.dart';

/// A configured tax rate, stored in basis points (1% = 100).
final class TaxRate extends Equatable {
  /// Creates a tax rate.
  const TaxRate({
    required this.id,
    required this.name,
    required this.rateBp,
    required this.isExempt,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  /// Unique id.
  final String id;

  /// Display name, e.g. "GST 18%".
  final String name;

  /// Rate in basis points.
  final int rateBp;

  /// Whether this entry represents tax-exempt supply.
  final bool isExempt;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Last update time (UTC).
  final DateTime updatedAt;

  /// Archive time, if archived.
  final DateTime? archivedAt;

  /// Whether the rate is archived.
  bool get isArchived => archivedAt != null;

  /// Rate as a percentage string (`1800` -> `18`, `1250` -> `12.5`).
  String get percentLabel {
    final whole = rateBp ~/ 100;
    final fraction = rateBp % 100;
    if (fraction == 0) {
      return '$whole';
    }
    final digits = fraction
        .toString()
        .padLeft(2, '0')
        .replaceFirst(RegExp(r'0+$'), '');
    return '$whole.$digits';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    rateBp,
    isExempt,
    createdAt,
    updatedAt,
    archivedAt,
  ];
}
