/// How dates are written on screens and printed documents.
///
/// Stored values never change: only the text shown to the user does. The
/// [name] of a style is what gets persisted, so do not rename members.
enum DateStyle {
  /// `15 Nov 2026` (the default).
  longMonth(pattern: 'd MMM yyyy', label: 'Day Month Year'),

  /// `15/11/2026`.
  dayMonthYear(pattern: 'dd/MM/yyyy', label: 'DD/MM/YYYY'),

  /// `11/15/2026`.
  monthDayYear(pattern: 'MM/dd/yyyy', label: 'MM/DD/YYYY'),

  /// `2026-11-15`.
  yearMonthDay(pattern: 'yyyy-MM-dd', label: 'YYYY-MM-DD');

  const DateStyle({required this.pattern, required this.label});

  /// `intl` pattern of the date part.
  final String pattern;

  /// Name shown in the settings screen.
  final String label;

  /// The style called [name] (as persisted), or [fallback] when the stored
  /// text is missing or unknown.
  static DateStyle parse(String? name, {DateStyle fallback = longMonth}) {
    for (final style in values) {
      if (style.name == name) {
        return style;
      }
    }
    return fallback;
  }
}

/// How digits are grouped and which separators numbers use.
enum NumberStyle {
  /// `12,34,567.89` (lakh/crore grouping; the default).
  indian(
    group: ',',
    decimal: '.',
    indianGrouping: true,
    symbolLocale: 'en_IN',
    label: '12,34,567.89',
  ),

  /// `1,234,567.89`.
  international(
    group: ',',
    decimal: '.',
    indianGrouping: false,
    symbolLocale: 'en_US',
    label: '1,234,567.89',
  ),

  /// `1.234.567,89`.
  european(
    group: '.',
    decimal: ',',
    indianGrouping: false,
    symbolLocale: 'de_DE',
    label: '1.234.567,89',
  ),

  /// `1 234 567,89` (a plain space between the groups).
  spaced(
    group: ' ',
    decimal: ',',
    indianGrouping: false,
    symbolLocale: 'fr_FR',
    label: '1 234 567,89',
  );

  const NumberStyle({
    required this.group,
    required this.decimal,
    required this.indianGrouping,
    required this.symbolLocale,
    required this.label,
  });

  /// Separator between digit groups.
  final String group;

  /// Separator before the fraction.
  final String decimal;

  /// Whether the groups are 3, 2, 2, ... digits instead of 3, 3, 3, ...
  final bool indianGrouping;

  /// Locale used only to look up the currency symbol.
  final String symbolLocale;

  /// Name shown in the settings screen (an example number).
  final String label;

  /// The style called [name] (as persisted), or [fallback].
  static NumberStyle parse(String? name, {NumberStyle fallback = indian}) {
    for (final style in values) {
      if (style.name == name) {
        return style;
      }
    }
    return fallback;
  }

  /// The style that matches a locale such as `en_IN` or `de_DE`.
  static NumberStyle fromLocale(String locale) {
    final language = locale.split(RegExp('[_-]')).first.toLowerCase();
    if (locale.toLowerCase() == 'en_in' ||
        language == 'hi' ||
        language == 'ta') {
      return indian;
    }
    const european = {'de', 'es', 'it', 'pt', 'nl', 'id', 'tr', 'da', 'el'};
    const spaced = {'fr', 'ru', 'pl', 'cs', 'sv', 'nb', 'fi', 'uk'};
    if (european.contains(language)) {
      return NumberStyle.european;
    }
    if (spaced.contains(language)) {
      return NumberStyle.spaced;
    }
    return international;
  }
}

/// Light, dark or follow the device.
enum ThemePreference {
  /// Follow the operating system (the default).
  system('System default'),

  /// Always light.
  light('Light'),

  /// Always dark.
  dark('Dark');

  const ThemePreference(this.label);

  /// Name shown in the settings screen.
  final String label;

  /// The preference called [name] (as persisted), or [system].
  static ThemePreference parse(String? name) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return system;
  }
}
