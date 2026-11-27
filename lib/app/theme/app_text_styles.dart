import 'package:material_ui/material_ui.dart';

/// Typography adjustments applied on top of the Material 3 defaults.
abstract final class AppTextStyles {
  /// Returns [base] with Inventrix weights applied.
  static TextTheme textTheme(TextTheme base) => base.copyWith(
    headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  );
}
