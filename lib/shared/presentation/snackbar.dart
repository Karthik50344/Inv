import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// Kind of message shown by [showAppMessage].
enum AppMessageType {
  /// Neutral information (the default look).
  info,

  /// Something worked.
  success,

  /// Something failed.
  error,
}

/// Shows a floating message at the bottom, replacing any current one.
///
/// [AppMessageType.success] and [AppMessageType.error] use tinted
/// backgrounds with an icon; [AppMessageType.info] keeps the plain look.
void showAppMessage(
  BuildContext context,
  String message, {
  AppMessageType type = AppMessageType.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final theme = Theme.of(context);
  final colors = context.appColors;
  final tone = switch (type) {
    AppMessageType.success => colors.success,
    AppMessageType.error => colors.danger,
    AppMessageType.info => null,
  };
  final icon = switch (type) {
    AppMessageType.success => Icons.check_circle_outline,
    AppMessageType.error => Icons.error_outline,
    AppMessageType.info => null,
  };
  // Background and text always come as a pair. Plain messages use the
  // snackbar theme's own pair (inverse surface); using the normal text color
  // on it made the text unreadable (dark on dark in light mode, light on
  // light in dark mode).
  final background =
      tone?.container ??
      theme.snackBarTheme.backgroundColor ??
      theme.colorScheme.inverseSurface;
  final foreground =
      tone?.onContainer ??
      theme.snackBarTheme.contentTextStyle?.color ??
      theme.colorScheme.onInverseSurface;
  final style = theme.textTheme.bodyMedium?.copyWith(color: foreground);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: background,
        // Tinted messages get a hairline in the tone color so they stand out
        // from the page behind them.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: tone == null
              ? BorderSide.none
              : BorderSide(color: tone.solid.withValues(alpha: 0.5)),
        ),
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message, style: style)),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: tone?.onContainer,
                onPressed: onAction ?? () {},
              ),
      ),
    );
}
