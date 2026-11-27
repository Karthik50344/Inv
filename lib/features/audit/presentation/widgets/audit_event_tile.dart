import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/features/audit/domain/entities/audit_event.dart';
import 'package:inventrix/features/audit/presentation/support/audit_labels.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// The tone and icon that suit an action.
({AppTone tone, IconData icon}) auditActionStyle(String action) {
  switch (action) {
    case 'voided':
    case 'cancelled':
    case 'reversed':
    case 'removed':
    case 'file_deleted':
      return (tone: AppTone.danger, icon: Icons.block_outlined);
    case 'created':
    case 'posted':
    case 'added':
    case 'recorded':
    case 'opening_stock':
      return (tone: AppTone.success, icon: Icons.add_circle_outline);
    case 'updated':
    case 'changed':
    case 'primary_changed':
      return (tone: AppTone.info, icon: Icons.edit_outlined);
    case 'chain_started':
      return (tone: AppTone.brand, icon: Icons.link);
    default:
      return (tone: AppTone.neutral, icon: Icons.history);
  }
}

/// One audit event in a list.
class AuditEventTile extends StatelessWidget {
  /// Creates the tile.
  const AuditEventTile({required this.event, required this.onTap, super.key});

  /// The event.
  final AuditEvent event;

  /// Opens the details.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = auditActionStyle(event.action);
    final colors = style.tone.colors(context);
    final summary = AuditLabels.summary(event);
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.container,
            child: Icon(style.icon, size: 18, color: colors.onContainer),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AuditLabels.title(event),
                  style: theme.textTheme.titleSmall,
                ),
                if (summary != null) ...[
                  AppSpacing.gap4,
                  Text(summary, style: theme.textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                AppSpacing.gap4,
                Text(
                  '${DateFormatter.dateTime(event.occurredAtUtc)}  ·  '
                  '${AuditLabels.actorShort(event.actor)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
