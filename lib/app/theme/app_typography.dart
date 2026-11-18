import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_colors.dart';

/// The type scale.
///
/// One family (Inter, bundled in `assets/fonts`, so it works offline) in four
/// weights. Figures use tabular numerals so amounts line up in columns and do
/// not jiggle while they change. Letter spacing tightens as size grows.
abstract final class AppTypography {
  /// Font family name declared in `pubspec.yaml`.
  static const String fontFamily = 'Inter';

  /// Equal-width digits.
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  static TextStyle _s(
    double size,
    FontWeight weight,
    double height, {
    required Color color,
    double letterSpacing = 0,
    List<FontFeature>? features,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: color,
    fontFeatures: features,
  );

  /// Material text theme mapped onto the scale:
  ///
  /// - display: `displaySmall` 32 / `displayMedium` 36 / `displayLarge` 44
  /// - page title: `headlineSmall` 22
  /// - section title: `titleMedium` 16
  /// - card title: `titleSmall` 15
  /// - body: `bodyLarge` 16, `bodyMedium` 14, `bodySmall` 12
  /// - label: `labelLarge` 14 (buttons), `labelMedium` 12, `labelSmall` 11
  static TextTheme textTheme(AppPalette p) {
    final c = p.textPrimary;
    return TextTheme(
      displayLarge: _s(44, FontWeight.w700, 1.14, color: c, letterSpacing: -1),
      displayMedium: _s(
        36,
        FontWeight.w700,
        1.17,
        color: c,
        letterSpacing: -0.8,
      ),
      displaySmall: _s(
        32,
        FontWeight.w700,
        1.19,
        color: c,
        letterSpacing: -0.6,
      ),
      headlineLarge: _s(
        28,
        FontWeight.w700,
        1.21,
        color: c,
        letterSpacing: -0.5,
      ),
      headlineMedium: _s(
        24,
        FontWeight.w700,
        1.25,
        color: c,
        letterSpacing: -0.4,
      ),
      headlineSmall: _s(
        22,
        FontWeight.w700,
        1.27,
        color: c,
        letterSpacing: -0.3,
      ),
      titleLarge: _s(
        20,
        FontWeight.w700,
        1.3,
        color: c,
        letterSpacing: -0.2,
      ),
      titleMedium: _s(
        16,
        FontWeight.w600,
        1.375,
        color: c,
        letterSpacing: -0.1,
      ),
      titleSmall: _s(15, FontWeight.w600, 1.33, color: c),
      bodyLarge: _s(16, FontWeight.w400, 1.5, color: c),
      bodyMedium: _s(14, FontWeight.w400, 1.43, color: c),
      bodySmall: _s(12, FontWeight.w400, 1.33, color: c),
      labelLarge: _s(
        14,
        FontWeight.w600,
        1.29,
        color: c,
        letterSpacing: 0.1,
      ),
      labelMedium: _s(
        12,
        FontWeight.w600,
        1.33,
        color: c,
        letterSpacing: 0.2,
      ),
      labelSmall: _s(
        11,
        FontWeight.w500,
        1.27,
        color: c,
        letterSpacing: 0.3,
      ),
    );
  }

  /// Extra styles that have no Material slot (see `AppTextTokens`).
  static AppTextStyles styles(AppPalette p) => AppTextStyles(
    display: _s(
      32,
      FontWeight.w700,
      1.19,
      color: p.textPrimary,
      letterSpacing: -0.6,
      features: tabularFigures,
    ),
    pageTitle: _s(
      22,
      FontWeight.w700,
      1.27,
      color: p.textPrimary,
      letterSpacing: -0.3,
    ),
    sectionTitle: _s(
      16,
      FontWeight.w600,
      1.375,
      color: p.textPrimary,
      letterSpacing: -0.1,
    ),
    cardTitle: _s(15, FontWeight.w600, 1.33, color: p.textPrimary),
    button: _s(
      14,
      FontWeight.w600,
      1.29,
      color: p.textPrimary,
      letterSpacing: 0.1,
    ),
    caption: _s(
      11,
      FontWeight.w500,
      1.27,
      color: p.textSecondary,
      letterSpacing: 0.3,
    ),
    tableHeading: _s(
      12,
      FontWeight.w600,
      1.33,
      color: p.textSecondary,
      letterSpacing: 0.4,
    ),
    financialLarge: _s(
      28,
      FontWeight.w700,
      1.21,
      color: p.textPrimary,
      letterSpacing: -0.5,
      features: tabularFigures,
    ),
    financialMedium: _s(
      18,
      FontWeight.w700,
      1.33,
      color: p.textPrimary,
      letterSpacing: -0.2,
      features: tabularFigures,
    ),
    financialSmall: _s(
      14,
      FontWeight.w600,
      1.29,
      color: p.textPrimary,
      features: tabularFigures,
    ),
  );
}

/// Styles beyond Material's 15 text slots, registered as a theme extension.
///
/// Read them with `context.appText`.
@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  /// Creates the set.
  const AppTextStyles({
    required this.display,
    required this.pageTitle,
    required this.sectionTitle,
    required this.cardTitle,
    required this.button,
    required this.caption,
    required this.tableHeading,
    required this.financialLarge,
    required this.financialMedium,
    required this.financialSmall,
  });

  /// Large hero figure.
  final TextStyle display;

  /// Title of a screen.
  final TextStyle pageTitle;

  /// Heading of a group of cards or rows.
  final TextStyle sectionTitle;

  /// Title inside a card or row.
  final TextStyle cardTitle;

  /// Button label.
  final TextStyle button;

  /// Small supporting text; secondary color.
  final TextStyle caption;

  /// Column heading in tables; secondary color.
  final TextStyle tableHeading;

  /// Headline amount (KPI card, invoice total).
  final TextStyle financialLarge;

  /// Amount in a card or summary row.
  final TextStyle financialMedium;

  /// Amount in a list row or table cell.
  final TextStyle financialSmall;

  @override
  AppTextStyles copyWith({
    TextStyle? display,
    TextStyle? pageTitle,
    TextStyle? sectionTitle,
    TextStyle? cardTitle,
    TextStyle? button,
    TextStyle? caption,
    TextStyle? tableHeading,
    TextStyle? financialLarge,
    TextStyle? financialMedium,
    TextStyle? financialSmall,
  }) => AppTextStyles(
    display: display ?? this.display,
    pageTitle: pageTitle ?? this.pageTitle,
    sectionTitle: sectionTitle ?? this.sectionTitle,
    cardTitle: cardTitle ?? this.cardTitle,
    button: button ?? this.button,
    caption: caption ?? this.caption,
    tableHeading: tableHeading ?? this.tableHeading,
    financialLarge: financialLarge ?? this.financialLarge,
    financialMedium: financialMedium ?? this.financialMedium,
    financialSmall: financialSmall ?? this.financialSmall,
  );

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) {
      return this;
    }
    return AppTextStyles(
      display: TextStyle.lerp(display, other.display, t)!,
      pageTitle: TextStyle.lerp(pageTitle, other.pageTitle, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      cardTitle: TextStyle.lerp(cardTitle, other.cardTitle, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      caption: TextStyle.lerp(caption, other.caption, t)!,
      tableHeading: TextStyle.lerp(tableHeading, other.tableHeading, t)!,
      financialLarge: TextStyle.lerp(financialLarge, other.financialLarge, t)!,
      financialMedium: TextStyle.lerp(
        financialMedium,
        other.financialMedium,
        t,
      )!,
      financialSmall: TextStyle.lerp(financialSmall, other.financialSmall, t)!,
    );
  }
}
