import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/audit/domain/entities/audit_query.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_operator_repository.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_query_repository.dart';
import 'package:inventrix/features/audit/domain/usecases/save_audit_operator_name.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/export_history_use_cases.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the audit dashboard.
final class AuditCenterState extends Equatable {
  /// Creates the state.
  const AuditCenterState({
    this.status = ViewStatus.initial,
    this.stats,
    this.recentExports = const [],
    this.operatorName,
    this.error,
  });

  /// Loading state.
  final ViewStatus status;

  /// Numbers from the real audit events.
  final AuditStats? stats;

  /// The newest exports.
  final List<ExportRecord> recentExports;

  /// The local operator named on new events, if one is set.
  final String? operatorName;

  /// A readable error, when loading failed.
  final String? error;

  @override
  List<Object?> get props => [status, stats, recentExports, operatorName, error];
}

/// Loads the audit dashboard.
class AuditCenterCubit extends Cubit<AuditCenterState> {
  /// Creates the cubit.
  AuditCenterCubit({
    required AuditQueryRepository queries,
    required ListExportHistory exports,
    required AuditOperatorRepository operators,
    required SaveAuditOperatorName saveOperator,
  }) : _queries = queries,
       _exports = exports,
       _operators = operators,
       _saveOperator = saveOperator,
       super(const AuditCenterState());

  final AuditQueryRepository _queries;
  final ListExportHistory _exports;
  final AuditOperatorRepository _operators;
  final SaveAuditOperatorName _saveOperator;

  /// Loads (or reloads) the numbers.
  Future<void> load() async {
    emit(
      AuditCenterState(
        status: ViewStatus.loading,
        stats: state.stats,
        recentExports: state.recentExports,
        operatorName: state.operatorName,
      ),
    );
    final stats = await _queries.stats();
    final value = stats.valueOrNull;
    if (value == null) {
      emit(
        AuditCenterState(
          status: ViewStatus.failure,
          error: stats.failureOrNull?.message ?? 'Could not load the audit trail.',
        ),
      );
      return;
    }
    final exports = (await _exports(limit: 3)).valueOrNull ?? const <ExportRecord>[];
    emit(
      AuditCenterState(
        status: value.totalEvents == 0 && exports.isEmpty
            ? ViewStatus.empty
            : ViewStatus.loaded,
        stats: value,
        recentExports: exports,
        operatorName: (await _operators.name()).valueOrNull,
      ),
    );
  }

  /// Sets the operator name. Returns the failure for the form, or `null`.
  Future<Failure?> saveOperatorName(String text) async {
    final result = await _saveOperator(text);
    if (result.isFailure) {
      return result.failureOrNull;
    }
    await load();
    return null;
  }
}
