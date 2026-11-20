import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/domain/entities/audit_verification.dart';
import 'package:inventrix/features/audit/domain/services/audit_canonical.dart';

/// Checks events one by one, in chain order.
///
/// Feed events in ascending sequence order to [accept]; it returns the first
/// problem found, or `null` while the chain is intact. It detects edited
/// events (hash mismatch) and removed, inserted or reordered events (broken
/// link). It cannot detect that the *last* events were deleted, or that the
/// whole chain was rebuilt consistently: compare against a retained
/// [AuditCheckpoint] for that.
final class AuditChainVerifier {
  /// Creates a verifier starting at the chain's beginning.
  AuditChainVerifier(this._hasher);

  final AuditHasher _hasher;
  String _expectedPrevious = kAuditGenesisHash;
  int _lastSequence = 0;
  int _checked = 0;
  bool _checkpointSeen = false;

  /// Events accepted so far.
  int get checked => _checked;

  /// Hash of the last accepted event.
  String get lastHash => _expectedPrevious;

  /// Whether the [checkpoint] given to [accept] was met.
  bool get checkpointSeen => _checkpointSeen;

  /// Examines the next [event]. Returns a failed verification, or `null`.
  AuditVerification? accept(AuditEvent event, {AuditCheckpoint? checkpoint}) {
    final sequence = event.sequence ?? _lastSequence + 1;
    AuditVerification problem(AuditProblem kind) => AuditVerification(
      problem: kind,
      eventsChecked: _checked,
      problemSequence: sequence,
      problemEventId: event.id,
    );
    if (sequence <= _lastSequence) {
      return problem(AuditProblem.outOfOrder);
    }
    if (event.previousEventHash != _expectedPrevious) {
      return problem(AuditProblem.brokenLink);
    }
    if (!event.isHashValid(_hasher)) {
      return problem(AuditProblem.hashMismatch);
    }
    _expectedPrevious = event.eventHash;
    _lastSequence = sequence;
    _checked++;
    if (checkpoint != null &&
        sequence == checkpoint.sequence &&
        event.eventHash == checkpoint.eventHash) {
      _checkpointSeen = true;
    }
    return null;
  }
}
