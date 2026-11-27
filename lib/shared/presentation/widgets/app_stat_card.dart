import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_card.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// A KPI tile: label, one headline value and a short supporting line.
///
/// The [value] is passed as text (already formatted, for example by
/// `MoneyFormatter`) so the card never decides how amounts look. The icon
/// tile uses [tone]; set [valueTone] to color the value itself (for example
/// red for "8 low-stock items").
class AppStatCard extends StatelessWidget {
  /// Creates a stat card.
  const AppStatCard({
    required this.label,
    required this.value,
    this.icon,
    this.subtitle,
    this.subtitleIcon,
    this.tone = AppTone.brand,
    this.valueTone,
    this.onTap,
    super.key,
  });

  /// What the number is ("Total sales").
  final String label;

  /// The formatted headline value.
  final String value;

  /// Icon shown in a tinted tile.
  final IconData? icon;

  /// Supporting line under the value ("vs last month").
  final String? subtitle;

  /// Optional icon before the [subtitle] (for example a trend arrow).
  final IconData? subtitleIcon;

  /// Color of the icon tile.
  final AppTone tone;

  /// Color of the value; defaults to normal text.
  final AppTone? valueTone;

  /// Tap handler; makes the card open a detail screen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.appColors;
    final toneColors = tone.colors(context);
    return MergeSemantics(
      child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    AppSpacing.hGap8,
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: toneColors.container,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          icon,
                          size: 18,
                          color: toneColors.onContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              AppSpacing.gap8,
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  value,
                  maxLines: 1,
                  style: context.appText.financialMedium.copyWith(
                    color: valueTone?.textColor(context),
                  ),
                ),
              ),
              if (subtitle != null) ...[
                AppSpacing.gap4,
                Row(
                  children: [
                    if (subtitleIcon != null) ...[
                      Icon(
                        subtitleIcon,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      AppSpacing.hGap4,
                    ],
                    Expanded(
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
    );
  }
}
