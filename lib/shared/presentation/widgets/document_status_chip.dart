import 'package:flutter/material.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/presentation/widgets/app_badge.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// Colored status pill for a document (draft, posted, voided, ...).
class DocumentStatusChip extends StatelessWidget {
  /// Creates the chip.
  const DocumentStatusChip({required this.status, super.key});

  /// The status to show.
  final DocumentStatus status;

  /// Tone of each status: finished is green, waiting is amber, in-progress
  /// is blue or brand, dead documents are red, and the rest are neutral.
  static AppTone toneOf(DocumentStatus status) => switch (status) {
    DocumentStatus.posted => AppTone.success,
    DocumentStatus.approved || DocumentStatus.authorized => AppTone.brand,
    DocumentStatus.pendingApproval => AppTone.warning,
    DocumentStatus.created => AppTone.info,
    DocumentStatus.voided || DocumentStatus.cancelled => AppTone.danger,
    _ => AppTone.neutral,
  };

  @override
  Widget build(BuildContext context) => AppBadge(
    key: Key('status_${status.dbName}'),
    label: status.label,
    tone: toneOf(status),
  );
}
