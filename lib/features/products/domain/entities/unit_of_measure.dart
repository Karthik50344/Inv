import 'package:equatable/equatable.dart';

/// A unit of measurement. [decimalPlaces] (0-3) limits quantity precision.
final class UnitOfMeasure extends Equatable {
  /// Creates a unit.
  const UnitOfMeasure({
    required this.id,
    required this.name,
    required this.symbol,
    required this.decimalPlaces,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  /// Unique id.
  final String id;

  /// Display name, e.g. "Kilogram".
  final String name;

  /// Short symbol, unique across all units (case-insensitive), e.g. "kg".
  final String symbol;

  /// Allowed decimal places for quantities in this unit (0-3).
  final int decimalPlaces;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Last update time (UTC).
  final DateTime updatedAt;

  /// Archive time, if archived.
  final DateTime? archivedAt;

  /// Whether the unit is archived.
  bool get isArchived => archivedAt != null;

  /// Copy with new details.
  UnitOfMeasure withDetails({
    required String name,
    required String symbol,
    required int decimalPlaces,
    required DateTime updatedAt,
  }) => UnitOfMeasure(
    id: id,
    name: name,
    symbol: symbol,
    decimalPlaces: decimalPlaces,
    createdAt: createdAt,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );

  /// Archived copy.
  UnitOfMeasure archived(DateTime at) => UnitOfMeasure(
    id: id,
    name: name,
    symbol: symbol,
    decimalPlaces: decimalPlaces,
    createdAt: createdAt,
    updatedAt: at,
    archivedAt: at,
  );

  /// Restored (active) copy.
  UnitOfMeasure restored(DateTime at) => UnitOfMeasure(
    id: id,
    name: name,
    symbol: symbol,
    decimalPlaces: decimalPlaces,
    createdAt: createdAt,
    updatedAt: at,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    symbol,
    decimalPlaces,
    createdAt,
    updatedAt,
    archivedAt,
  ];
}
