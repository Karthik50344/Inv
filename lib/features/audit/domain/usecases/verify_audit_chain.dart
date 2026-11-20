import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/audit/domain/entities/audit_verification.dart';
import 'package:inventrix/features/audit/domain/repositories/audit_event_repository.dart';
import 'package:inventrix/features/audit/domain/services/audit_canonical.dart';
import 'package:inventrix/features/audit/domain/services/audit_chain_verifier.dart';

/// Verifies the whole audit chain and, optionally, a retained checkpoint.
final class VerifyAuditChain {
  /// Creates the use case.
  const VerifyAuditChain({
    required AuditEventRepository repository,
    required AuditHasher hasher,
    int pageSize = 500,
  }) : _repository = repository,
       _hasher = hasher,
       _pageSize = pageSize;

  final AuditEventRepository _repository;
  final AuditHasher _hasher;
  final int _pageSize;

  /// Walks every event in order. With a [checkpoint], also requires that
  /// the chain still contains the event it names.
  Future<Result<AuditVerification>> call({AuditCheckpoint? checkpoint}) async {
    final verifier = AuditChainVerifier(_hasher);
    var after = 0;
    while (true) {
      final loaded = await _repository.page(
        afterSequence: after,
        limit: _pageSize,
      );
      final events = loaded.valueOrNull;
      if (events == null) {
        return Result.failure(loaded.failureOrNull!);
      }
      if (events.isEmpty) {
        break;
      }
      for (final event in events) {
        final problem = verifier.accept(event, checkpoint: checkpoint);
        if (problem != null) {
          return Result.success(problem);
        }
        after = event.sequence ?? after + 1;
      }
    }
    if (checkpoint != null && !verifier.checkpointSeen) {
      return Result.success(
        AuditVerification(
          problem: AuditProblem.checkpointMissing,
          eventsChecked: verifier.checked,
          problemSequence: checkpoint.sequence,
          checkpointChecked: true,
        ),
      );
    }
    return Result.success(
      AuditVerification.valid(
        verifier.checked,
        checkpointChecked: checkpoint != null,
      ),
    );
  }
}

/// Reads the current end of the chain as a checkpoint to keep elsewhere.
final class CreateAuditCheckpoint {
  /// Creates the use case.
  const CreateAuditCheckpoint({
    required AuditEventRepository repository,
    required Clock clock,
  }) : _repository = repository,
       _clock = clock;

  final AuditEventRepository _repository;
  final Clock _clock;

  /// The latest event's position and hash, or `null` for an empty chain.
  Future<Result<AuditCheckpoint?>> call() async {
    final latest = await _repository.latest();
    final event = latest.valueOrNull;
    if (event == null) {
      return latest.isFailure
          ? Result.failure(latest.failureOrNull!)
          : const Result.success(null);
    }
    return Result.success(
      AuditCheckpoint(
        sequence: event.sequence!,
        eventHash: event.eventHash,
        takenAtUtc: _clock.now().toUtc(),
      ),
    );
  }
}
