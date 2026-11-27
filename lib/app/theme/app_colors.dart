import 'package:material_ui/material_ui.dart';

/// Every color of the Inventrix design system, for one brightness.
///
/// The two palettes are designed separately (not inverted): the light one
/// tints its backgrounds instead of using white everywhere, the dark one is a
/// navy ladder instead of pure black. Text pairs meet WCAG AA (4.5:1) on every
/// surface they can sit on, and control borders meet 3:1.
///
/// Feature widgets must not read this class. They use `Theme.of(context)`
/// (`colorScheme`) or the `AppColorTokens` extension, both built from here.
@immutable
final class AppPalette {
  /// Creates a palette.
  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surfaceLowest,
    required this.surfaceLow,
    required this.surface,
    required this.surfaceContainer,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.surfaceElevated,
    required this.inputFill,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.primaryText,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.inversePrimary,
    required this.navBackground,
    required this.scrim,
    required this.shadow,
    required this.chart,
  });

  /// Light or dark.
  final Brightness brightness;

  /// Page background behind every screen.
  final Color background;

  /// Lowest tonal surface (Material `surfaceContainerLowest`).
  final Color surfaceLowest;

  /// Low tonal surface (Material `surfaceContainerLow`).
  final Color surfaceLow;

  /// Card and panel surface.
  final Color surface;

  /// Subtle fill inside cards: chips, grouped rows, table headers.
  final Color surfaceContainer;

  /// Stronger fill: pressed rows, progress tracks.
  final Color surfaceHigh;

  /// Strongest neutral fill.
  final Color surfaceHighest;

  /// Dialogs, bottom sheets and menus.
  final Color surfaceElevated;

  /// Text field background.
  final Color inputFill;

  /// Hairline border for cards and dividers between blocks.
  final Color border;

  /// Border of interactive controls (inputs, outlined buttons); at least 3:1 against its surface.
  final Color borderStrong;

  /// Thin separator lines inside a card or list.
  final Color divider;

  /// Main text.
  final Color textPrimary;

  /// Supporting text and captions; at least 4.5:1 on every surface.
  final Color textSecondary;

  /// Disabled text and icons (exempt from contrast rules).
  final Color textDisabled;

  /// Brand color: filled buttons, switches, focus rings.
  final Color primary;

  /// Content on [primary].
  final Color onPrimary;

  /// Selected chips, active navigation indicator.
  final Color primaryContainer;

  /// Content on [primaryContainer].
  final Color onPrimaryContainer;

  /// Brand-colored text and icons on a surface (links, selected labels).
  final Color primaryText;

  /// Secondary accent (informational blue).
  final Color secondary;

  /// Content on [secondary].
  final Color onSecondary;

  /// Container for [secondary].
  final Color secondaryContainer;

  /// Content on [secondaryContainer].
  final Color onSecondaryContainer;

  /// Tertiary accent (positive green).
  final Color tertiary;

  /// Content on [tertiary].
  final Color onTertiary;

  /// Container for [tertiary].
  final Color tertiaryContainer;

  /// Content on [tertiaryContainer].
  final Color onTertiaryContainer;

  /// Success / in stock / paid.
  final Color success;

  /// Content on a solid [success] fill.
  final Color onSuccess;

  /// Tinted success background.
  final Color successContainer;

  /// Content on [successContainer].
  final Color onSuccessContainer;

  /// Warning / low stock / partial.
  final Color warning;

  /// Content on a solid [warning] fill.
  final Color onWarning;

  /// Tinted warning background.
  final Color warningContainer;

  /// Content on [warningContainer].
  final Color onWarningContainer;

  /// Error / out of stock / overdue.
  final Color error;

  /// Content on a solid [error] fill.
  final Color onError;

  /// Tinted error background.
  final Color errorContainer;

  /// Content on [errorContainer].
  final Color onErrorContainer;

  /// Information / in transit / draft.
  final Color info;

  /// Content on a solid [info] fill.
  final Color onInfo;

  /// Tinted information background.
  final Color infoContainer;

  /// Content on [infoContainer].
  final Color onInfoContainer;

  /// Snackbars and tooltips.
  final Color inverseSurface;

  /// Content on [inverseSurface].
  final Color onInverseSurface;

  /// Primary color on [inverseSurface].
  final Color inversePrimary;

  /// Bottom bar and navigation rail background.
  final Color navBackground;

  /// Modal barrier color.
  final Color scrim;

  /// Shadow color.
  final Color shadow;

  /// Series colors for charts, in order of use. At least 3:1 on [surface].
  final List<Color> chart;

  /// Palette for [brightness].
  static AppPalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The light palette.
  static const AppPalette light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFF2F4F9),
    surfaceLowest: Color(0xFFFFFFFF),
    surfaceLow: Color(0xFFF7F8FC),
    surface: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFEDF0F7),
    surfaceHigh: Color(0xFFE4E8F2),
    surfaceHighest: Color(0xFFDCE1EE),
    surfaceElevated: Color(0xFFFFFFFF),
    inputFill: Color(0xFFF7F8FC),
    border: Color(0xFFD9DEEB),
    borderStrong: Color(0xFF7D87A2),
    divider: Color(0xFFE6E9F2),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF4A5570),
    textDisabled: Color(0xFF98A1B8),
    primary: Color(0xFF4F46E5),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE3E1FD),
    onPrimaryContainer: Color(0xFF28208F),
    primaryText: Color(0xFF4338CA),
    secondary: Color(0xFF2563EB),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDCE8FD),
    onSecondaryContainer: Color(0xFF123C8F),
    tertiary: Color(0xFF0B7A55),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD5F3E6),
    onTertiaryContainer: Color(0xFF064E36),
    success: Color(0xFF0B7A55),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD5F3E6),
    onSuccessContainer: Color(0xFF064E36),
    warning: Color(0xFF9A5206),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFDEBCB),
    onWarningContainer: Color(0xFF6B3A05),
    error: Color(0xFFC9302C),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFCE0DE),
    onErrorContainer: Color(0xFF7F1D1B),
    info: Color(0xFF1D5FD1),
    onInfo: Color(0xFFFFFFFF),
    infoContainer: Color(0xFFDCE8FD),
    onInfoContainer: Color(0xFF123C8F),
    inverseSurface: Color(0xFF1E293B),
    onInverseSurface: Color(0xFFF1F5F9),
    inversePrimary: Color(0xFFA8A2FF),
    navBackground: Color(0xFFFFFFFF),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF0F172A),
    chart: <Color>[
      Color(0xFF4F46E5),
      Color(0xFF0284C7),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFFDB2777),
      Color(0xFF7C3AED),
    ],
  );

  /// The dark palette.
  static const AppPalette dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF0B1220),
    surfaceLowest: Color(0xFF090F1C),
    surfaceLow: Color(0xFF0F1729),
    surface: Color(0xFF121A2D),
    surfaceContainer: Color(0xFF18223A),
    surfaceHigh: Color(0xFF1E2A45),
    surfaceHighest: Color(0xFF26324F),
    surfaceElevated: Color(0xFF1A2540),
    inputFill: Color(0xFF18223A),
    border: Color(0xFF2A3654),
    borderStrong: Color(0xFF6A78A6),
    divider: Color(0xFF1F2A44),
    textPrimary: Color(0xFFE8ECF6),
    textSecondary: Color(0xFFA3AEC7),
    textDisabled: Color(0xFF5F6B86),
    primary: Color(0xFF5B50EA),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF2B2670),
    onPrimaryContainer: Color(0xFFD9D6FF),
    primaryText: Color(0xFFA8A2FF),
    secondary: Color(0xFF5B9BFF),
    onSecondary: Color(0xFF0B1220),
    secondaryContainer: Color(0xFF15305F),
    onSecondaryContainer: Color(0xFFC7DCFF),
    tertiary: Color(0xFF34D399),
    onTertiary: Color(0xFF06281E),
    tertiaryContainer: Color(0xFF0F3A2E),
    onTertiaryContainer: Color(0xFFA7F3D0),
    success: Color(0xFF34D399),
    onSuccess: Color(0xFF06281E),
    successContainer: Color(0xFF0F3A2E),
    onSuccessContainer: Color(0xFFA7F3D0),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF2A1B00),
    warningContainer: Color(0xFF3D2E0A),
    onWarningContainer: Color(0xFFFDE68A),
    error: Color(0xFFF87171),
    onError: Color(0xFF3B0A0A),
    errorContainer: Color(0xFF3F1519),
    onErrorContainer: Color(0xFFFECACA),
    info: Color(0xFF60A5FA),
    onInfo: Color(0xFF0B1B33),
    infoContainer: Color(0xFF12294D),
    onInfoContainer: Color(0xFFBFDBFE),
    inverseSurface: Color(0xFFE8ECF6),
    onInverseSurface: Color(0xFF121A2D),
    inversePrimary: Color(0xFF4F46E5),
    navBackground: Color(0xFF121A2D),
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
    chart: <Color>[
      Color(0xFF8179F5),
      Color(0xFF38BDF8),
      Color(0xFF34D399),
      Color(0xFFFBBF24),
      Color(0xFFF472B6),
      Color(0xFFA78BFA),
    ],
  );
}
