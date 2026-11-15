import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/inventory/domain/entities/reconciliation.dart';
import 'package:inventrix/features/inventory/domain/usecases/reconcile_inventory.dart';
import 'package:inventrix/features/inventory/domain/usecases/repair_inventory_balances.dart';

/// Phase of the reconciliation screen.
enum ReconciliationStatus { idle, running, done, repairing, failure }

/// State of the reconciliation screen.
final class ReconciliationState extends Equatable {
  /// Creates a state.
  const ReconciliationState({
    this.status = ReconciliationStatus.idle,
    this.report,
    this.repairedCount,
    this.message,
  });

  /// Current phase.
  final ReconciliationStatus status;

  /// Latest report, if one has been produced.
  final ReconciliationReport? report;

  /// Number of balances corrected by the last repair.
  final int? repairedCount;

  /// One-shot user-facing message.
  final String? message;

  @override
  List<Object?> get props => [status, report, repairedCount, message];
}

/// Checks balances against the ledger and offers an explicit repair.
class ReconciliationCubit extends Cubit<ReconciliationState> {
  /// Creates the cubit.
  ReconciliationCubit({
    required ReconcileInventory reconcile,
    required RepairInventoryBalances repair,
  }) : _reconcile = reconcile,
       _repair = repair,
       super(const ReconciliationState());

  final ReconcileInventory _reconcile;
  final RepairInventoryBalances _repair;

  /// Runs the comparison.
  Future<void> run() async {
    emit(const ReconciliationState(status: ReconciliationStatus.running));
    final result = await _reconcile();
    if (isClosed) {
      return;
    }
    result.when(
      success: (report) => emit(
        ReconciliationState(status: ReconciliationStatus.done, report: report),
      ),
      failure: (failure) => emit(
        ReconciliationState(
          status: ReconciliationStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }

  /// Rewrites mismatching balances from the ledger, then re-checks.
  Future<void> repair() async {
    if (state.status == ReconciliationStatus.repairing) {
      return;
    }
    emit(
      ReconciliationState(
        status: ReconciliationStatus.repairing,
        report: state.report,
      ),
    );
    final result = await _repair();
    if (isClosed) {
      return;
    }
    final failure = result.failureOrNull;
    if (failure != null) {
      emit(
        ReconciliationState(
          status: ReconciliationStatus.failure,
          report: state.report,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final count = result.valueOrNull;
    final check = await _reconcile();
    if (isClosed) {
      return;
    }
    emit(
      ReconciliationState(
        status: ReconciliationStatus.done,
        report: check.valueOrNull,
        repairedCount: count,
        message: check.failureOrNull?.userMessage,
      ),
    );
  }
}
