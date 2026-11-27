import 'package:material_ui/material_ui.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_badge.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// Colored label for a document status.
class SalesStatusChip extends StatelessWidget {
  /// Creates the chip.
  const SalesStatusChip({required this.status, super.key});

  /// Status to show.
  final DocumentStatus status;

  /// The tone used for [status] (shared with other document lists).
  static AppTone toneFor(DocumentStatus status) => switch (status) {
    DocumentStatus.posted => AppTone.success,
    DocumentStatus.approved || DocumentStatus.authorized => AppTone.info,
    DocumentStatus.pendingApproval => AppTone.warning,
    DocumentStatus.voided || DocumentStatus.cancelled => AppTone.danger,
    _ => AppTone.neutral,
  };

  @override
  Widget build(BuildContext context) => AppBadge(
    key: Key('status_${status.dbName}'),
    label: status.label,
    tone: toneFor(status),
  );
}
