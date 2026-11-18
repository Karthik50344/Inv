import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_radius.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_tone.dart';

/// The standard card: tonal surface, hairline border, a faint shadow in light
/// mode only. Pass [onTap] to make it tappable (with ripple and semantics).
///
/// Use [tone] sparingly, for cards that are themselves an alert (for example
/// a low-stock summary); it tints the fill and border.
class AppCard extends StatelessWidget {
  /// Creates a card.
  const AppCard({
    required this.child,
    this.padding = AppSpacing.card,
    this.margin,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.tone,
    super.key,
  });

  /// Content.
  final Widget child;

  /// Space inside the card.
  final EdgeInsetsGeometry padding;

  /// Space outside the card.
  final EdgeInsetsGeometry? margin;

  /// Tap handler.
  final VoidCallback? onTap;

  /// Long-press handler.
  final VoidCallback? onLongPress;

  /// Outlines the card in the brand color.
  final bool selected;

  /// Tints the card as an alert of this tone.
  final AppTone? tone;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final scheme = Theme.of(context).colorScheme;
    final toneColors = tone?.colors(context);
    final borderColor = selected
        ? colors.primaryText
        : (toneColors == null
              ? colors.border
              : toneColors.solid.withValues(alpha: 0.4));
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        boxShadow: colors.cardShadow,
      ),
      child: Material(
        color: toneColors?.container ?? scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardRadius,
          side: BorderSide(color: borderColor, width: selected ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: onTap == null && onLongPress == null
            ? Padding(padding: padding, child: child)
            : InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                child: Padding(padding: padding, child: child),
              ),
      ),
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}
