import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// Look of an [AppIconButton].
enum AppIconButtonVariant {
  /// Icon only.
  standard,

  /// Solid brand fill.
  filled,

  /// Soft brand tint.
  tonal,

  /// Bordered.
  outlined,
}

/// An icon button that always has a [tooltip], which is also its
/// accessibility label, and a 48 px touch target.
class AppIconButton extends StatelessWidget {
  /// Creates an icon button.
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.variant = AppIconButtonVariant.standard,
    this.showBadge = false,
    super.key,
  });

  /// The icon.
  final IconData icon;

  /// Hint and screen-reader label.
  final String tooltip;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// Look.
  final AppIconButtonVariant variant;

  /// Shows a small dot (unread, filter active).
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final Widget glyph = showBadge
        ? Badge(
            smallSize: 8,
            backgroundColor: context.appColors.danger.solid,
            child: Icon(icon),
          )
        : Icon(icon);
    return switch (variant) {
      AppIconButtonVariant.standard => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: glyph,
      ),
      AppIconButtonVariant.filled => IconButton.filled(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: glyph,
      ),
      AppIconButtonVariant.tonal => IconButton.filledTonal(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: glyph,
      ),
      AppIconButtonVariant.outlined => IconButton.outlined(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: glyph,
      ),
    };
  }
}
