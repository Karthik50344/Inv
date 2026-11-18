import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// Heading of a group of cards or rows, with an optional "View all" action.
class AppSectionHeader extends StatelessWidget {
  /// Creates a header.
  const AppSectionHeader({
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.s16,
      AppSpacing.s24,
      AppSpacing.s16,
      AppSpacing.s8,
    ),
    super.key,
  });

  /// Heading text.
  final String title;

  /// Supporting line.
  final String? subtitle;

  /// Text of the action link; shown only with [onAction].
  final String? actionLabel;

  /// Called when the action link is tapped.
  final VoidCallback? onAction;

  /// A custom widget at the end; replaces the action link.
  final Widget? trailing;

  /// Space around the header.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final Widget? end =
        trailing ??
        (onAction == null || actionLabel == null
            ? null
            : TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(actionLabel!),
              ));
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(title, style: context.appText.sectionTitle),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (end != null) end,
        ],
      ),
    );
  }
}
