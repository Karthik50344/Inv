import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// The meaning a badge, stat card or banner carries.
///
/// Every component that shows status takes a tone instead of raw colors, so
/// "low stock" looks the same on the dashboard, the product list and a report.
enum AppTone {
  /// Selected or primary things.
  brand,

  /// In stock, paid, healthy.
  success,

  /// Low stock, partial, needs attention.
  warning,

  /// Out of stock, overdue, destructive.
  danger,

  /// Informational, draft, in progress.
  info,

  /// Inactive, archived, no particular meaning.
  neutral;

  /// The four colors of this tone in the current theme.
  AppStatusColor colors(BuildContext context) {
    final tokens = context.appColors;
    return switch (this) {
      AppTone.brand => tokens.brand,
      AppTone.success => tokens.success,
      AppTone.warning => tokens.warning,
      AppTone.danger => tokens.danger,
      AppTone.info => tokens.info,
      AppTone.neutral => tokens.neutral,
    };
  }

  /// Color for text or an icon of this tone sitting directly on a surface
  /// (at least 4.5:1 in both themes).
  Color textColor(BuildContext context) {
    final tokens = context.appColors;
    return switch (this) {
      AppTone.brand => tokens.primaryText,
      AppTone.neutral => tokens.textSecondary,
      _ => colors(context).solid,
    };
  }
}
