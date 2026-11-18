import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// Shared look of chart tooltips and axis labels.
abstract final class ChartStyle {
  /// Tooltip background.
  static Color tooltipColor(BuildContext context) =>
      context.appColors.surfaceElevated;

  /// Tooltip text.
  static TextStyle tooltipText(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      );

  /// Axis label.
  static TextStyle? axisText(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
        color: context.appColors.textSecondary,
      );
}
