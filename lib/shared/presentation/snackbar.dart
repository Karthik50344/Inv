import 'package:flutter/material.dart';
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
  final style = Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: tone?.onContainer);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: tone?.container,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: tone?.onContainer, size: 20),
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
