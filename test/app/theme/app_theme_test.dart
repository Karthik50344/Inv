import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/theme/app_theme.dart';

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
}
