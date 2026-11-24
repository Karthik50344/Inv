import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/audit/domain/entities/audit_verification.dart';
import 'package:inventrix/features/audit/domain/usecases/verify_audit_chain.dart';

/// State of the integrity screen.
final class AuditIntegrityState extends Equatable {
  /// Creates the state.
  const AuditIntegrityState({
    this.running = false,
    this.result,
    this.checkpoint,
    this.comparedWithCheckpoint = false,
    this.error,
    this.checkpointError,
  });

  /// Whether a check is running.
  final bool running;

  /// The last verification.
  final AuditVerification? result;

  /// The checkpoint created in this session, to keep outside the device.
  final AuditCheckpoint? checkpoint;

  /// Whether [result] was compared with a retained checkpoint.
  final bool comparedWithCheckpoint;

  /// A readable error.
  final String? error;

  /// A problem with the typed checkpoint.
  final String? checkpointError;

  @override
  List<Object?> get props => [
    running,
    result,
    checkpoint,
    comparedWithCheckpoint,
    error,
    checkpointError,
  ];
}

/// Runs the audit chain verification and checkpoints.
class AuditIntegrityCubit extends Cubit<AuditIntegrityState> {
  /// Creates the cubit.
  AuditIntegrityCubit({
    required VerifyAuditChain verify,
    required CreateAuditCheckpoint createCheckpoint,
    required Clock clock,
  }) : _verify = verify,
       _createCheckpoint = createCheckpoint,
       _clock = clock,
       super(const AuditIntegrityState());

  final VerifyAuditChain _verify;
  final CreateAuditCheckpoint _createCheckpoint;
  final Clock _clock;

  /// Verifies the whole chain.
  Future<void> verify() async {
    emit(
      AuditIntegrityState(running: true, checkpoint: state.checkpoint),
    );
    final result = await _verify();
    final value = result.valueOrNull;
    emit(
      AuditIntegrityState(
        result: value,
        checkpoint: state.checkpoint,
        error: value == null
            ? result.failureOrNull?.message ?? 'The check could not be completed.'
            : null,
      ),
    );
  }

  /// Verifies the chain and requires it to contain the event named by a
  /// checkpoint kept outside the device ([sequenceText] and [hashText] as
  /// typed by the user).
  Future<void> verifyAgainst(String sequenceText, String hashText) async {
    final sequence = int.tryParse(sequenceText.trim());
    final hash = hashText.trim().toLowerCase();
    if (sequence == null || sequence < 1 || !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      emit(
        AuditIntegrityState(
          result: state.result,
          checkpoint: state.checkpoint,
          checkpointError:
              'Enter the event number and the 64-character code exactly as '
              'it was saved.',
        ),
      );
      return;
    }
    emit(AuditIntegrityState(running: true, checkpoint: state.checkpoint));
    final result = await _verify(
      checkpoint: AuditCheckpoint(
        sequence: sequence,
        eventHash: hash,
        takenAtUtc: _clock.now().toUtc(),
      ),
    );
    final value = result.valueOrNull;
    emit(
      AuditIntegrityState(
        result: value,
        checkpoint: state.checkpoint,
        comparedWithCheckpoint: value != null,
        error: value == null
            ? result.failureOrNull?.message ?? 'The check could not be completed.'
            : null,
      ),
    );
  }

  /// Reads the end of the chain as a checkpoint to keep elsewhere.
  Future<void> makeCheckpoint() async {
    final result = await _createCheckpoint();
    emit(
      AuditIntegrityState(
        result: state.result,
        checkpoint: result.valueOrNull,
        comparedWithCheckpoint: state.comparedWithCheckpoint,
        error: result.isFailure ? result.failureOrNull!.message : null,
      ),
    );
  }
}
