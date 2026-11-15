import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_colors.dart';
import 'package:inventrix/app/theme/app_text_styles.dart';

/// Material 3 light and dark themes.
///
/// Component themes (cards, inputs, dialogs) are added together with the
/// first screens that need them, once the Flutter SDK version is pinned.
abstract final class AppTheme {
  /// Light theme.
  static ThemeData light() => _build(Brightness.light);

  /// Dark theme.
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    return base.copyWith(
      textTheme: AppTextStyles.textTheme(base.textTheme),
      visualDensity: VisualDensity.standard,
    );
  }
}
