import 'package:inventrix/features/audit/domain/entities/audit_actor.dart';

/// Tells the audit recorder who is acting right now.
///
/// Today: the local operator the business entered (unverified), else the
/// device. A future authenticated-user provider can replace it without
/// touching any use case.
abstract interface class AuditActorProvider {
  /// The current actor.
  Future<AuditActor> current();
}
