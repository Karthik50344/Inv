import 'package:flutter/material.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';

/// Colored label for a document status.
class PurchaseStatusChip extends StatelessWidget {
  /// Creates the chip.
  const PurchaseStatusChip({required this.status, super.key});

  /// Status to show.
  final DocumentStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      DocumentStatus.posted => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      DocumentStatus.approved || DocumentStatus.authorized => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      DocumentStatus.pendingApproval => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      DocumentStatus.voided || DocumentStatus.cancelled => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Chip(
      key: Key('status_${status.dbName}'),
      label: Text(status.label),
      backgroundColor: background,
      labelStyle: TextStyle(color: foreground),
      visualDensity: VisualDensity.compact,
      side: BorderSide.none,
      padding: EdgeInsets.zero,
    );
  }
}
