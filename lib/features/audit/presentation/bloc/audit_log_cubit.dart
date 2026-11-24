import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_query.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_query_repository.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the audit log screen.
final class AuditLogState extends Equatable {
  /// Creates the state.
  const AuditLogState({
    this.status = ViewStatus.initial,
    this.events = const [],
    this.filter = const AuditEventFilter(),
    this.hasMore = false,
    this.loadingMore = false,
    this.eventTypes = const [],
    this.entityTypes = const [],
    this.error,
  });

  /// Loading state of the first page.
  final ViewStatus status;

  /// Events loaded so far, newest first.
  final List<AuditEvent> events;

  /// Current criteria.
  final AuditEventFilter filter;

  /// Whether another page may exist.
  final bool hasMore;

  /// Whether the next page is loading.
  final bool loadingMore;

  /// Event types present, for the filter sheet.
  final List<String> eventTypes;

  /// Record types present, for the filter sheet.
  final List<String> entityTypes;

  /// A readable error.
  final String? error;

  /// How many filter criteria are active (the search text is not counted).
  int get activeFilterCount =>
      (filter.from != null || filter.to != null ? 1 : 0) +
      (filter.eventType != null ? 1 : 0) +
      (filter.entityType != null ? 1 : 0) +
      (filter.actor.trim().isNotEmpty ? 1 : 0) +
      (filter.reference.trim().isNotEmpty ? 1 : 0);

  /// Copy with changes.
  AuditLogState copyWith({
    ViewStatus? status,
    List<AuditEvent>? events,
    AuditEventFilter? filter,
    bool? hasMore,
    bool? loadingMore,
    List<String>? eventTypes,
    List<String>? entityTypes,
    String? error,
    bool clearError = false,
  }) => AuditLogState(
    status: status ?? this.status,
    events: events ?? this.events,
    filter: filter ?? this.filter,
    hasMore: hasMore ?? this.hasMore,
    loadingMore: loadingMore ?? this.loadingMore,
    eventTypes: eventTypes ?? this.eventTypes,
    entityTypes: entityTypes ?? this.entityTypes,
    error: clearError ? null : error ?? this.error,
  );

  @override
  List<Object?> get props => [
    status,
    events,
    filter,
    hasMore,
    loadingMore,
    eventTypes,
    entityTypes,
    error,
  ];
}

/// Search, filter and page through the audit events.
class AuditLogCubit extends Cubit<AuditLogState> {
  /// Creates the cubit. [debounce] delays typing searches.
  AuditLogCubit({
    required AuditQueryRepository queries,
    this.debounce = const Duration(milliseconds: 300),
    AuditEventFilter? initial,
  }) : _queries = queries,
       super(AuditLogState(filter: initial ?? const AuditEventFilter()));

  final AuditQueryRepository _queries;

  /// Delay before a typed search runs.
  final Duration debounce;
  Timer? _timer;
  int _generation = 0;

  /// Loads the filter lists and the first page.
  Future<void> load() async {
    final types = await _queries.eventTypes();
    final entities = await _queries.entityTypes();
    emit(
      state.copyWith(
        eventTypes: types.valueOrNull ?? const [],
        entityTypes: entities.valueOrNull ?? const [],
      ),
    );
    await _reload();
  }

  /// Runs a search for [text] after a short pause.
  void search(String text) {
    _timer?.cancel();
    _timer = Timer(debounce, () => apply(_with(search: text)));
  }

  /// Replaces the criteria and reloads from the first page.
  Future<void> apply(AuditEventFilter filter) async {
    emit(state.copyWith(filter: filter));
    await _reload();
  }

  /// Clears every criterion except the search text.
  Future<void> clearFilters() => apply(AuditEventFilter(search: state.filter.search, limit: state.filter.limit));

  /// Loads the next page.
  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore || state.status != ViewStatus.loaded) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    final next = state.filter.nextPage();
    final result = await _queries.search(next);
    if (generation != _generation) {
      return;
    }
    final page = result.valueOrNull;
    if (page == null) {
      emit(state.copyWith(loadingMore: false, error: result.failureOrNull?.message));
      return;
    }
    emit(
      state.copyWith(
        events: [...state.events, ...page],
        filter: next,
        hasMore: page.length >= next.limit,
        loadingMore: false,
        clearError: true,
      ),
    );
  }

  AuditEventFilter _with({String? search}) {
    final f = state.filter;
    return AuditEventFilter(
      search: search ?? f.search,
      from: f.from,
      to: f.to,
      eventType: f.eventType,
      entityType: f.entityType,
      actor: f.actor,
      reference: f.reference,
      limit: f.limit,
    );
  }

  Future<void> _reload() async {
    final generation = ++_generation;
    emit(state.copyWith(status: ViewStatus.loading, loadingMore: false, clearError: true));
    final first = AuditEventFilter(
      search: state.filter.search,
      from: state.filter.from,
      to: state.filter.to,
      eventType: state.filter.eventType,
      entityType: state.filter.entityType,
      actor: state.filter.actor,
      reference: state.filter.reference,
      limit: state.filter.limit,
    );
    final result = await _queries.search(first);
    if (generation != _generation) {
      return;
    }
    final page = result.valueOrNull;
    if (page == null) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          error: result.failureOrNull?.message ?? 'Could not load the audit log.',
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        status: page.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        events: page,
        filter: first,
        hasMore: page.length >= first.limit,
      ),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
