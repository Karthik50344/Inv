import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/theme/app_colors.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/app/theme/app_typography.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('light theme uses Material 3 and a light scheme', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.light);
  });

  test('dark theme uses Material 3 and a dark scheme', () {
    final theme = AppTheme.dark();
    expect(theme.useMaterial3, isTrue);
    expect(theme.colorScheme.brightness, Brightness.dark);
  });

  test('light and dark schemes differ', () {
    expect(
      AppTheme.light().colorScheme.surface ==
          AppTheme.dark().colorScheme.surface,
      isFalse,
    );
  });

  test('both themes use the bundled Inter family', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, AppTypography.fontFamily);
      expect(theme.textTheme.titleLarge?.fontFamily, AppTypography.fontFamily);
    }
  });

  test('theme carries the token extensions', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.extension<AppColorTokens>(), isNotNull);
      expect(theme.extension<AppTextStyles>(), isNotNull);
    }
  });

  test('financial styles use tabular figures', () {
    final styles = AppTheme.light().extension<AppTextStyles>()!;
    for (final s in [
      styles.financialLarge,
      styles.financialMedium,
      styles.financialSmall,
    ]) {
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });

  group('palette design', () {
    test('light page is tinted, not plain white', () {
      expect(AppPalette.light.background, isNot(const Color(0xFFFFFFFF)));
    });

    test('dark page is navy, not pure black', () {
      expect(AppPalette.dark.background, isNot(const Color(0xFF000000)));
    });

    test('cards stand out from the page in both themes', () {
      for (final p in [AppPalette.light, AppPalette.dark]) {
        expect(p.surface, isNot(p.background));
      }
    });

    test('chart palette has six distinct colors', () {
      for (final p in [AppPalette.light, AppPalette.dark]) {
        expect(p.chart.toSet().length, 6);
      }
    });
  });

  group('contrast (WCAG)', () {
    final palettes = <String, AppPalette>{
      'light': AppPalette.light,
      'dark': AppPalette.dark,
    };

    test('text meets 4.5:1 on every surface it can sit on', () {
      for (final entry in palettes.entries) {
        final p = entry.value;
        final surfaces = [
          p.background,
          p.surface,
          p.surfaceLow,
          p.surfaceContainer,
          p.surfaceHigh,
          p.surfaceHighest,
          p.surfaceElevated,
          p.inputFill,
        ];
        for (final s in surfaces) {
          expect(
            _contrast(p.textPrimary, s),
            greaterThanOrEqualTo(7),
            reason: '${entry.key}: primary text on $s',
          );
          expect(
            _contrast(p.textSecondary, s),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: secondary text on $s',
          );
        }
      }
    });

    test('colored text meets 4.5:1 on page, card and container', () {
      for (final entry in palettes.entries) {
        final p = entry.value;
        for (final fg in [p.primaryText, p.success, p.warning, p.error, p.info]) {
          for (final bg in [p.background, p.surface, p.surfaceContainer]) {
            expect(
              _contrast(fg, bg),
              greaterThanOrEqualTo(4.5),
              reason: '${entry.key}: $fg on $bg',
            );
          }
        }
      }
    });

    test('every on-color meets 4.5:1 on its fill', () {
      for (final entry in palettes.entries) {
        final p = entry.value;
        final pairs = <(Color, Color)>[
          (p.onPrimary, p.primary),
          (p.onSecondary, p.secondary),
          (p.onTertiary, p.tertiary),
          (p.onSuccess, p.success),
          (p.onWarning, p.warning),
          (p.onError, p.error),
          (p.onInfo, p.info),
          (p.onPrimaryContainer, p.primaryContainer),
          (p.onSecondaryContainer, p.secondaryContainer),
          (p.onTertiaryContainer, p.tertiaryContainer),
          (p.onSuccessContainer, p.successContainer),
          (p.onWarningContainer, p.warningContainer),
          (p.onErrorContainer, p.errorContainer),
          (p.onInfoContainer, p.infoContainer),
          (p.onInverseSurface, p.inverseSurface),
        ];
        for (final (fg, bg) in pairs) {
          expect(
            _contrast(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}: $fg on $bg',
          );
        }
      }
    });

    test('control borders meet 3:1 on cards and fields', () {
      for (final entry in palettes.entries) {
        final p = entry.value;
        for (final bg in [p.surface, p.inputFill]) {
          expect(
            _contrast(p.borderStrong, bg),
            greaterThanOrEqualTo(3),
            reason: '${entry.key}: border on $bg',
          );
        }
      }
    });

    test('chart colors meet 3:1 on cards', () {
      for (final entry in palettes.entries) {
        final p = entry.value;
        for (final c in p.chart) {
          expect(
            _contrast(c, p.surface),
            greaterThanOrEqualTo(3),
            reason: '${entry.key}: chart $c',
          );
        }
      }
    });
  });

  group('tokens', () {
    test('lerp at the ends returns the matching theme', () {
      final light = AppColorTokens.fromPalette(AppPalette.light);
      final dark = AppColorTokens.fromPalette(AppPalette.dark);
      expect(light.lerp(dark, 0).border, light.border);
      expect(light.lerp(dark, 1).border, dark.border);
      expect(light.lerp(dark, 1).chart, dark.chart);
    });

    test('chartColor wraps around', () {
      final t = AppColorTokens.fromPalette(AppPalette.light);
      expect(t.chartColor(0), t.chartColor(t.chart.length));
    });

    test('dark cards have no shadow, light cards do', () {
      expect(AppColorTokens.fromPalette(AppPalette.dark).cardShadow, isEmpty);
      expect(
        AppColorTokens.fromPalette(AppPalette.light).cardShadow,
        isNotEmpty,
      );
    });

    testWidgets('context helpers fall back on a plain ThemeData', (
      tester,
    ) async {
      late AppColorTokens colors;
      late AppTextStyles text;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              colors = context.appColors;
              text = context.appText;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(colors.brightness, Brightness.dark);
      expect(text.financialLarge.fontFamily, AppTypography.fontFamily);
    });
  });

  testWidgets('theme switches immediately without rebuilding the route', (
    tester,
  ) async {
    final mode = ValueNotifier<ThemeMode>(ThemeMode.light);
    addTearDown(mode.dispose);
    Color? seen;
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: mode,
        builder: (context, value, _) => MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: value,
          home: Builder(
            builder: (context) {
              seen = Theme.of(context).scaffoldBackgroundColor;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    expect(seen, AppPalette.light.background);
    mode.value = ThemeMode.dark;
    await tester.pumpAndSettle();
    expect(seen, AppPalette.dark.background);
  });
}
