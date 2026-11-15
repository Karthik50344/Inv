import 'package:equatable/equatable.dart';
import 'package:inventrix/features/products/domain/entities/unit_of_measure.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the units screen.
final class UnitState extends Equatable {
  /// Creates a state.
  const UnitState({
    this.status = ViewStatus.initial,
    this.units = const [],
    this.query = '',
    this.includeArchived = false,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Loaded units.
  final List<UnitOfMeasure> units;

  /// Current search text.
  final String query;

  /// Whether archived units are shown.
  final bool includeArchived;

  /// One-shot user-facing message.
  final String? message;

  /// Copy with changes; [message] is cleared unless provided.
  UnitState copyWith({
    ViewStatus? status,
    List<UnitOfMeasure>? units,
    String? query,
    bool? includeArchived,
    String? message,
  }) => UnitState(
    status: status ?? this.status,
    units: units ?? this.units,
    query: query ?? this.query,
    includeArchived: includeArchived ?? this.includeArchived,
    message: message,
  );

  @override
  List<Object?> get props => [status, units, query, includeArchived, message];
}
