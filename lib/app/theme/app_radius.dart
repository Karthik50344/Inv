import 'package:flutter/widgets.dart';

/// Corner radii. One value per kind of element, so shapes stay consistent.
abstract final class AppRadius {
  /// Badges, small chips, thumbnails.
  static const double small = 8;

  /// Buttons, text fields, dropdowns, list rows, snackbars.
  static const double control = 12;

  /// Cards and panels.
  static const double card = 16;

  /// Navigation indicator and floating bars.
  static const double nav = 16;

  /// Dialogs and menus.
  static const double dialog = 20;

  /// Top corners of bottom sheets.
  static const double sheet = 24;

  /// Fully rounded (pills, filter chips).
  static const double pill = 999;

  /// [small] as a radius.
  static const BorderRadius smallRadius = BorderRadius.all(
    Radius.circular(small),
  );

  /// [control] as a radius.
  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );

  /// [card] as a radius.
  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );

  /// [dialog] as a radius.
  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(dialog),
  );

  /// Rounded top corners for bottom sheets.
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );

  /// [pill] as a radius.
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}
