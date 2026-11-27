import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// A small status pill ("In stock", "Overdue", "Draft").
///
/// Soft by default (tinted background, strong text); [solid] fills it with
/// the tone color for the rare badge that must shout.
class AppBadge extends StatelessWidget {
  /// Creates a badge.
  const AppBadge({
    required this.label,
    this.tone = AppTone.neutral,
    this.icon,
    this.solid = false,
    super.key,
  });

  /// Text.
  final String label;

  /// Meaning, which decides the colors.
  final AppTone tone;

  /// Optional leading icon.
  final IconData? icon;

  /// Fills with the strong tone color instead of the soft tint.
  final bool solid;

  @override
  Widget build(BuildContext context) {
    final colors = tone.colors(context);
    final foreground = solid ? colors.onSolid : colors.onContainer;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: solid ? colors.solid : colors.container,
        borderRadius: AppRadius.smallRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4 - 1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: foreground),
              AppSpacing.hGap4,
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
