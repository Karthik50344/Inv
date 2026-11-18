import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_colors.dart';
import 'package:inventrix/app/theme/app_component_themes.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/app/theme/app_typography.dart';

/// Material 3 light and dark themes for Inventrix.
///
/// Both are assembled from [AppPalette] (colors), [AppTypography] (type) and
/// [AppComponentThemes] (components), so nothing here hardcodes a value.
/// Screens read colors through `Theme.of(context).colorScheme` or
/// `context.appColors`, and extra text styles through `context.appText`.
abstract final class AppTheme {
  /// Light theme.
  static ThemeData light() => _build(AppPalette.light);

  /// Dark theme.
  static ThemeData dark() => _build(AppPalette.dark);

  /// The Material color scheme for [p].
  ///
  /// `secondaryContainer` deliberately reuses the brand container so tonal
  /// buttons, selected segments and navigation indicators are all indigo.
  /// The informational blue lives in `AppColorTokens.info`.
  static ColorScheme colorScheme(AppPalette p) => ColorScheme(
    brightness: p.brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.onPrimaryContainer,
    secondary: p.secondary,
    onSecondary: p.onSecondary,
    secondaryContainer: p.primaryContainer,
    onSecondaryContainer: p.onPrimaryContainer,
    tertiary: p.tertiary,
    onTertiary: p.onTertiary,
    tertiaryContainer: p.tertiaryContainer,
    onTertiaryContainer: p.onTertiaryContainer,
    error: p.error,
    onError: p.onError,
    errorContainer: p.errorContainer,
    onErrorContainer: p.onErrorContainer,
    surface: p.surface,
    onSurface: p.textPrimary,
    onSurfaceVariant: p.textSecondary,
    surfaceDim: p.background,
    surfaceBright: p.surface,
    surfaceContainerLowest: p.surfaceLowest,
    surfaceContainerLow: p.surfaceLow,
    surfaceContainer: p.surfaceContainer,
    surfaceContainerHigh: p.surfaceHigh,
    surfaceContainerHighest: p.surfaceHighest,
    outline: p.borderStrong,
    outlineVariant: p.border,
    shadow: p.shadow,
    scrim: p.scrim,
    inverseSurface: p.inverseSurface,
    onInverseSurface: p.onInverseSurface,
    inversePrimary: p.inversePrimary,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(AppPalette p) {
    final textTheme = AppTypography.textTheme(p);
    final styles = AppTypography.styles(p);
    final input = AppComponentThemes.inputDecoration(p, textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: colorScheme(p),
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      dividerColor: p.divider,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppComponentThemes.appBar(p, textTheme),
      cardTheme: AppComponentThemes.card(p),
      inputDecorationTheme: input,
      dropdownMenuTheme: AppComponentThemes.dropdownMenu(p, textTheme, input),
      filledButtonTheme: AppComponentThemes.filledButton(styles.button),
      elevatedButtonTheme: AppComponentThemes.elevatedButton(p, styles.button),
      outlinedButtonTheme: AppComponentThemes.outlinedButton(p, styles.button),
      textButtonTheme: AppComponentThemes.textButton(p, styles.button),
      floatingActionButtonTheme: AppComponentThemes.fab(p, styles.button),
      chipTheme: AppComponentThemes.chip(p, textTheme),
      navigationBarTheme: AppComponentThemes.navigationBar(p, textTheme),
      navigationRailTheme: AppComponentThemes.navigationRail(p, textTheme),
      dialogTheme: AppComponentThemes.dialog(p, textTheme),
      bottomSheetTheme: AppComponentThemes.bottomSheet(p),
      snackBarTheme: AppComponentThemes.snackBar(p, textTheme),
      dividerTheme: AppComponentThemes.divider(p),
      listTileTheme: AppComponentThemes.listTile(p, textTheme),
      expansionTileTheme: AppComponentThemes.expansionTile(p),
      switchTheme: AppComponentThemes.switchTheme(p),
      checkboxTheme: AppComponentThemes.checkbox(p),
      radioTheme: AppComponentThemes.radio(p),
      segmentedButtonTheme: AppComponentThemes.segmentedButton(p, textTheme),
      progressIndicatorTheme: AppComponentThemes.progress(p),
      tooltipTheme: AppComponentThemes.tooltip(p, textTheme),
      popupMenuTheme: AppComponentThemes.popupMenu(p, textTheme),
      datePickerTheme: AppComponentThemes.datePicker(p),
      textSelectionTheme: AppComponentThemes.textSelection(p),
      extensions: <ThemeExtension<dynamic>>[
        AppColorTokens.fromPalette(p),
        styles,
      ],
    );
  }
}
