import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/features/audit/presentation/support/audit_labels.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';

/// A readable before / after comparison. Only fields that exist on either
/// side are listed; unchanged fields are marked as such.
class ValueDiff extends StatelessWidget {
  /// Creates the comparison.
  const ValueDiff({this.previous, this.next, super.key});

  /// Values before the change.
  final Map<String, Object?>? previous;

  /// Values after the change.
  final Map<String, Object?>? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final before = previous ?? const <String, Object?>{};
    final after = next ?? const <String, Object?>{};
    final keys = {...before.keys, ...after.keys}.toList()..sort();
    if (keys.isEmpty) {
      return Text('No values were recorded for this event.', style: theme.textTheme.bodyMedium);
    }
    final creating = previous == null;
    final removing = next == null;
    return Column(
      children: [
        for (final key in keys)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: _Row(
              label: AuditLabels.field(key),
              before: before.containsKey(key) ? AuditLabels.value(before[key]) : null,
              after: after.containsKey(key) ? AuditLabels.value(after[key]) : null,
              changed: creating || removing || before[key] != after[key],
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.before,
    required this.after,
    required this.changed,
  });

  final String label;
  final String? before;
  final String? after;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final danger = AppTone.danger.colors(context);
    final success = AppTone.success.colors(context);
    return AppCard(
      tone: changed ? null : AppTone.neutral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
              if (!changed) const AppBadge(label: 'Unchanged'),
            ],
          ),
          AppSpacing.gap8,
          if (before != null)
            _Value(
              title: 'Before',
              text: before!,
              colors: changed && after != null ? danger : null,
            ),
          if (before != null && after != null) AppSpacing.gap4,
          if (after != null)
            _Value(
              title: 'After',
              text: after!,
              colors: changed ? success : null,
            ),
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.title, required this.text, this.colors});

  final String title;
  final String text;
  final AppStatusColor? colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: colors?.container,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(color: colors?.onContainer),
          ),
          SelectableText(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors?.onContainer),
          ),
        ],
      ),
    );
  }
}
