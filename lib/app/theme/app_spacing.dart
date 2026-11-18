import 'package:flutter/widgets.dart';

/// Spacing scale. Use these instead of numeric literals.
///
/// The names are the values: [s8] is 8 logical pixels.
abstract final class AppSpacing {
  /// 4.
  static const double s4 = 4;

  /// 8.
  static const double s8 = 8;

  /// 12.
  static const double s12 = 12;

  /// 16.
  static const double s16 = 16;

  /// 20.
  static const double s20 = 20;

  /// 24.
  static const double s24 = 24;

  /// 32.
  static const double s32 = 32;

  /// 40.
  static const double s40 = 40;

  /// 48.
  static const double s48 = 48;

  /// Horizontal page margin on phones.
  static const double pageGutter = s16;

  /// Gap between cards in a list or grid.
  static const double cardGap = s12;

  /// Padding inside a card.
  static const double cardPadding = s16;

  /// Standard page padding.
  static const EdgeInsets page = EdgeInsets.symmetric(
    horizontal: pageGutter,
    vertical: s16,
  );

  /// Padding inside a card.
  static const EdgeInsets card = EdgeInsets.all(cardPadding);

  /// Vertical gap widgets.
  static const SizedBox gap4 = SizedBox(height: s4);

  /// 8 high.
  static const SizedBox gap8 = SizedBox(height: s8);

  /// 12 high.
  static const SizedBox gap12 = SizedBox(height: s12);

  /// 16 high.
  static const SizedBox gap16 = SizedBox(height: s16);

  /// 24 high.
  static const SizedBox gap24 = SizedBox(height: s24);

  /// 4 wide.
  static const SizedBox hGap4 = SizedBox(width: s4);

  /// 8 wide.
  static const SizedBox hGap8 = SizedBox(width: s8);

  /// 12 wide.
  static const SizedBox hGap12 = SizedBox(width: s12);

  /// 16 wide.
  static const SizedBox hGap16 = SizedBox(width: s16);
}
