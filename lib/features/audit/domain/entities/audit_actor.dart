import 'package:equatable/equatable.dart';

/// Who or what performed an audited action.
enum AuditActorType {
  /// A person identified by a name typed on this device. Not verified.
  localOperator('local_operator'),

  /// The application on this device, no person identified.
  device('device'),

  /// A verified, authenticated user. Reserved for future multi-user support:
  /// Inventrix has no authentication today and never records this type.
  authenticatedUser('authenticated_user'),

  /// Work started by the system itself (migrations, repairs, rebuilds).
  system('system');

  const AuditActorType(this.code);

  /// Stable storage code.
  final String code;

  /// The type stored as [code]; unknown codes become [device].
  static AuditActorType parse(String code) {
    for (final value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return device;
  }
}

/// The actor of an audit event.
///
/// Inventrix cannot prove who is holding the device, so a local operator is
/// only a label the business chose. Only [AuditActorType.authenticatedUser]
/// is [isVerified].
final class AuditActor extends Equatable {
  /// Creates an actor.
  const AuditActor({
    required this.type,
    required this.displayName,
    this.id,
  });

  /// The application running on this device.
  static const AuditActor device = AuditActor(
    type: AuditActorType.device,
    displayName: 'This device',
  );

  /// The system itself.
  static const AuditActor system = AuditActor(
    type: AuditActorType.system,
    displayName: 'System',
  );

  /// A local operator with a typed [name].
  factory AuditActor.localOperator(String name) => AuditActor(
    type: AuditActorType.localOperator,
    displayName: name,
    id: 'local',
  );

  /// Kind of actor.
  final AuditActorType type;

  /// Stable identifier (`local` for local operators, a user id later).
  final String? id;

  /// Name shown in the log.
  final String displayName;

  /// Whether the identity was verified by authentication.
  bool get isVerified => type == AuditActorType.authenticatedUser;

  @override
  List<Object?> get props => [type, id, displayName];
}
