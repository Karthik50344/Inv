import 'package:flutter/material.dart';

/// Shadows. Deliberately few and faint: separation comes from borders and
/// tonal surfaces first, shadows only lift things that float.
///
/// Dark surfaces get no card shadow (a shadow on navy is invisible and only
/// muddies the border); floating elements keep one so they still separate
/// from the content under them.
abstract final class AppShadows {
  /// Resting card. Light only; empty in dark mode.
  static List<BoxShadow> card(Brightness brightness) =>
      brightness == Brightness.dark
      ? const <BoxShadow>[]
      : const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ];

  /// Sticky bars and floating buttons.
  static List<BoxShadow> floating(Brightness brightness) =>
      brightness == Brightness.dark
      ? const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ]
      : const <BoxShadow>[
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ];

  /// Dialogs, sheets and menus.
  static List<BoxShadow> overlay(Brightness brightness) =>
      brightness == Brightness.dark
      ? const <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ]
      : const <BoxShadow>[
          BoxShadow(
            color: Color(0x290F172A),
            blurRadius: 40,
            offset: Offset(0, 16),
          ),
        ];
}
