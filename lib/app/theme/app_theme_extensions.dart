import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_colors.dart';
import 'package:inventrix/app/theme/app_shadows.dart';
import 'package:inventrix/app/theme/app_typography.dart';

/// A meaning (success, warning, ...) expressed as four colors, so badges,
/// chips, banners and icons all use the same combinations.
@immutable
class AppStatusColor {
  /// Creates the set.
  const AppStatusColor({
    required this.solid,
    required this.onSolid,
    required this.container,
    required this.onContainer,
  });

  /// Strong color: icons, progress, solid badges, text on a surface.
  final Color solid;

  /// Content on a [solid] fill.
  final Color onSolid;

  /// Tinted background for soft badges and banners.
  final Color container;

  /// Content on [container].
  final Color onContainer;

  /// Interpolates every color.
  static AppStatusColor lerp(AppStatusColor a, AppStatusColor b, double t) =>
      AppStatusColor(
        solid: Color.lerp(a.solid, b.solid, t)!,
        onSolid: Color.lerp(a.onSolid, b.onSolid, t)!,
        container: Color.lerp(a.container, b.container, t)!,
        onContainer: Color.lerp(a.onContainer, b.onContainer, t)!,
      );
}

/// Semantic colors that Material's `ColorScheme` has no slot for, plus the
/// neutral tokens the components share. Read with `context.appColors`.
@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  /// Creates the tokens.
  const AppColorTokens({
    required this.brightness,
    required this.brand,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.neutral,
    required this.primaryText,
    required this.textSecondary,
    required this.textDisabled,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.inputFill,
    required this.surfaceElevated,
    required this.navBackground,
    required this.chart,
  });

  /// Builds the tokens from [p].
  factory AppColorTokens.fromPalette(AppPalette p) => AppColorTokens(
    brightness: p.brightness,
    brand: AppStatusColor(
      solid: p.primary,
      onSolid: p.onPrimary,
      container: p.primaryContainer,
      onContainer: p.onPrimaryContainer,
    ),
    success: AppStatusColor(
      solid: p.success,
      onSolid: p.onSuccess,
      container: p.successContainer,
      onContainer: p.onSuccessContainer,
    ),
    warning: AppStatusColor(
      solid: p.warning,
      onSolid: p.onWarning,
      container: p.warningContainer,
      onContainer: p.onWarningContainer,
    ),
    danger: AppStatusColor(
      solid: p.error,
      onSolid: p.onError,
      container: p.errorContainer,
      onContainer: p.onErrorContainer,
    ),
    info: AppStatusColor(
      solid: p.info,
      onSolid: p.onInfo,
      container: p.infoContainer,
      onContainer: p.onInfoContainer,
    ),
    neutral: AppStatusColor(
      solid: p.textSecondary,
      onSolid: p.surface,
      container: p.surfaceHigh,
      onContainer: p.textSecondary,
    ),
    primaryText: p.primaryText,
    textSecondary: p.textSecondary,
    textDisabled: p.textDisabled,
    border: p.border,
    borderStrong: p.borderStrong,
    divider: p.divider,
    inputFill: p.inputFill,
    surfaceElevated: p.surfaceElevated,
    navBackground: p.navBackground,
    chart: p.chart,
  );

  /// Light or dark; decides the shadows.
  final Brightness brightness;

  /// Brand (indigo): selected and primary things.
  final AppStatusColor brand;

  /// In stock, paid, healthy, positive change.
  final AppStatusColor success;

  /// Low stock, partially paid, needs attention.
  final AppStatusColor warning;

  /// Out of stock, overdue, failed, destructive.
  final AppStatusColor danger;

  /// Informational, draft, in progress.
  final AppStatusColor info;

  /// Inactive, archived, voided, cancelled.
  final AppStatusColor neutral;

  /// Brand-colored text and icons that sit on a surface.
  final Color primaryText;

  /// Supporting text.
  final Color textSecondary;

  /// Disabled text and icons.
  final Color textDisabled;

  /// Hairline border of cards.
  final Color border;

  /// Border of interactive controls.
  final Color borderStrong;

  /// Separator line inside cards and lists.
  final Color divider;

  /// Text field fill.
  final Color inputFill;

  /// Dialogs, sheets and menus.
  final Color surfaceElevated;

  /// Navigation bar background.
  final Color navBackground;

  /// Chart series colors, in order.
  final List<Color> chart;

  /// Shadow of a resting card (empty in dark mode).
  List<BoxShadow> get cardShadow => AppShadows.card(brightness);

  /// Shadow of floating bars and buttons.
  List<BoxShadow> get floatingShadow => AppShadows.floating(brightness);

  /// Shadow of dialogs, sheets and menus.
  List<BoxShadow> get overlayShadow => AppShadows.overlay(brightness);

  /// Chart color for series [index]; wraps around.
  Color chartColor(int index) => chart[index % chart.length];

  @override
  AppColorTokens copyWith({
    Brightness? brightness,
    AppStatusColor? brand,
    AppStatusColor? success,
    AppStatusColor? warning,
    AppStatusColor? danger,
    AppStatusColor? info,
    AppStatusColor? neutral,
    Color? primaryText,
    Color? textSecondary,
    Color? textDisabled,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? inputFill,
    Color? surfaceElevated,
    Color? navBackground,
    List<Color>? chart,
  }) => AppColorTokens(
    brightness: brightness ?? this.brightness,
    brand: brand ?? this.brand,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    info: info ?? this.info,
    neutral: neutral ?? this.neutral,
    primaryText: primaryText ?? this.primaryText,
    textSecondary: textSecondary ?? this.textSecondary,
    textDisabled: textDisabled ?? this.textDisabled,
    border: border ?? this.border,
    borderStrong: borderStrong ?? this.borderStrong,
    divider: divider ?? this.divider,
    inputFill: inputFill ?? this.inputFill,
    surfaceElevated: surfaceElevated ?? this.surfaceElevated,
    navBackground: navBackground ?? this.navBackground,
    chart: chart ?? this.chart,
  );

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }
    return AppColorTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      brand: AppStatusColor.lerp(brand, other.brand, t),
      success: AppStatusColor.lerp(success, other.success, t),
      warning: AppStatusColor.lerp(warning, other.warning, t),
      danger: AppStatusColor.lerp(danger, other.danger, t),
      info: AppStatusColor.lerp(info, other.info, t),
      neutral: AppStatusColor.lerp(neutral, other.neutral, t),
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      chart: <Color>[
        for (var i = 0; i < chart.length; i++)
          Color.lerp(chart[i], other.chart[i % other.chart.length], t)!,
      ],
    );
  }
}

/// Shortcuts to the design tokens.
extension AppThemeContext on BuildContext {
  /// Semantic colors. Falls back to the matching palette when the theme is a
  /// plain `ThemeData` (some widget tests), so widgets never crash.
  AppColorTokens get appColors {
    final theme = Theme.of(this);
    return theme.extension<AppColorTokens>() ??
        AppColorTokens.fromPalette(AppPalette.of(theme.brightness));
  }

  /// Extra text styles (financial values, table headings, ...).
  AppTextStyles get appText {
    final theme = Theme.of(this);
    return theme.extension<AppTextStyles>() ??
        AppTypography.styles(AppPalette.of(theme.brightness));
  }
}
