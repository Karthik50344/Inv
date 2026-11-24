import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_query_repository.dart';
import 'package:inventrix/features/audit/domain/services/audit_canonical.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the event detail screen.
final class AuditEventState extends Equatable {
  /// Creates the state.
  const AuditEventState({
    this.status = ViewStatus.initial,
    this.event,
    this.related = const [],
    this.hashValid,
    this.error,
  });

  /// Loading state.
  final ViewStatus status;

  /// The event.
  final AuditEvent? event;

  /// Other events of the same operation, in order.
  final List<AuditEvent> related;

  /// Whether the event's stored hash matches its content. This checks the
  /// one event; the integrity screen checks the whole chain.
  final bool? hashValid;

  /// A readable error.
  final String? error;

  @override
  List<Object?> get props => [status, event, related, hashValid, error];
}

/// Loads one audit event with the events of the same operation.
class AuditEventCubit extends Cubit<AuditEventState> {
  /// Creates the cubit.
  AuditEventCubit({
    required AuditQueryRepository queries,
    required AuditHasher hasher,
  }) : _queries = queries,
       _hasher = hasher,
       super(const AuditEventState());

  final AuditQueryRepository _queries;
  final AuditHasher _hasher;

  /// Loads event [id].
  Future<void> load(String id) async {
    emit(const AuditEventState(status: ViewStatus.loading));
    final loaded = await _queries.byId(id);
    final event = loaded.valueOrNull;
    if (event == null) {
      emit(
        AuditEventState(
          status: ViewStatus.failure,
          error: loaded.failureOrNull?.message ?? 'This audit event no longer exists.',
        ),
      );
      return;
    }
    final related = (await _queries.byCorrelation(event.correlationId)).valueOrNull ?? const <AuditEvent>[];
    emit(
      AuditEventState(
        status: ViewStatus.loaded,
        event: event,
        related: [for (final e in related) if (e.id != event.id) e],
        hashValid: event.isHashValid(_hasher),
      ),
    );
  }
}
