import 'package:equatable/equatable.dart';

/// What went wrong when verifying the chain.
enum AuditProblem {
  /// Nothing: the chain is intact.
  none,

  /// An event's stored hash does not match its content: the event was
  /// edited.
  hashMismatch,

  /// An event does not point at the hash of the event before it: an event
  /// was removed, inserted or reordered.
  brokenLink,

  /// Sequence numbers do not increase.
  outOfOrder,

  /// A retained checkpoint is not part of the chain: the chain was cut or
  /// rebuilt after the checkpoint was taken.
  checkpointMissing,
}

/// A hash and position retained outside the database (printed, e-mailed,
/// stored in an export manifest) to detect later truncation or rebuilding.
final class AuditCheckpoint extends Equatable {
  /// Creates a checkpoint.
  const AuditCheckpoint({
    required this.sequence,
    required this.eventHash,
    required this.takenAtUtc,
  });

  /// Sequence number of the last event covered.
  final int sequence;

  /// Hash of that event.
  final String eventHash;

  /// When the checkpoint was taken.
  final DateTime takenAtUtc;

  @override
  List<Object?> get props => [sequence, eventHash, takenAtUtc];
}

/// Outcome of verifying the audit chain.
final class AuditVerification extends Equatable {
  /// Creates a result.
  const AuditVerification({
    required this.problem,
    required this.eventsChecked,
    this.problemSequence,
    this.problemEventId,
    this.checkpointChecked = false,
  });

  /// The chain is intact after [eventsChecked] events.
  const AuditVerification.valid(int eventsChecked, {bool checkpointChecked = false})
    : this(
        problem: AuditProblem.none,
        eventsChecked: eventsChecked,
        checkpointChecked: checkpointChecked,
      );

  /// What was found.
  final AuditProblem problem;

  /// Events examined before stopping.
  final int eventsChecked;

  /// Sequence number of the first bad event.
  final int? problemSequence;

  /// Id of the first bad event.
  final String? problemEventId;

  /// Whether a retained checkpoint was compared.
  final bool checkpointChecked;

  /// Whether the chain is intact.
  bool get isValid => problem == AuditProblem.none;

  @override
  List<Object?> get props => [
    problem,
    eventsChecked,
    problemSequence,
    problemEventId,
    checkpointChecked,
  ];
}
