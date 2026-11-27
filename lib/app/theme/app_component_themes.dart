import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:inventrix/app/theme/app_colors.dart';
import 'package:inventrix/app/theme/app_radius.dart';

/// Material component themes, all derived from [AppPalette].
///
/// Colors that Material already derives correctly from the color scheme (the
/// fill of a filled button, for instance) are left alone on purpose, so tonal
/// and filled variants keep their own looks.
abstract final class AppComponentThemes {
  static const RoundedRectangleBorder _controlShape = RoundedRectangleBorder(
    borderRadius: AppRadius.controlRadius,
  );

  static const WidgetStateProperty<Color?> _noOverlayTint =
      WidgetStatePropertyAll<Color?>(Colors.transparent);

  /// Flat app bar on the page background.
  static AppBarTheme appBar(AppPalette p, TextTheme t) {
    final dark = p.brightness == Brightness.dark;
    return AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: t.titleLarge,
      iconTheme: IconThemeData(color: p.textPrimary),
      actionsIconTheme: IconThemeData(color: p.textPrimary),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      ),
    );
  }

  /// Bordered, flat card.
  static CardThemeData card(AppPalette p) => CardThemeData(
    color: p.surface,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.cardRadius,
      side: BorderSide(color: p.border),
    ),
  );

  /// Filled text fields with a visible 3:1 border and an indigo focus ring.
  static InputDecorationTheme inputDecoration(AppPalette p, TextTheme t) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: AppRadius.controlRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    Color stateColor(Set<WidgetState> s) {
      if (s.contains(WidgetState.disabled)) {
        return p.textDisabled;
      }
      if (s.contains(WidgetState.error)) {
        return p.error;
      }
      if (s.contains(WidgetState.focused)) {
        return p.primaryText;
      }
      return p.textSecondary;
    }

    return InputDecorationTheme(
      filled: true,
      fillColor: p.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(p.borderStrong),
      enabledBorder: border(p.borderStrong),
      disabledBorder: border(p.border),
      focusedBorder: border(p.primaryText, 2),
      errorBorder: border(p.error),
      focusedErrorBorder: border(p.error, 2),
      hintStyle: t.bodyMedium?.copyWith(color: p.textSecondary),
      labelStyle: WidgetStateTextStyle.resolveWith(
        (s) => t.bodyMedium!.copyWith(color: stateColor(s)),
      ),
      floatingLabelStyle: WidgetStateTextStyle.resolveWith(
        (s) => t.bodyMedium!.copyWith(color: stateColor(s)),
      ),
      helperStyle: t.bodySmall?.copyWith(color: p.textSecondary),
      errorStyle: t.bodySmall?.copyWith(color: p.error),
      prefixIconColor: WidgetStateColor.resolveWith(stateColor),
      suffixIconColor: WidgetStateColor.resolveWith(stateColor),
    );
  }

  /// Dropdown menus share the text field look.
  static DropdownMenuThemeData dropdownMenu(
    AppPalette p,
    TextTheme t,
    InputDecorationTheme input,
  ) => DropdownMenuThemeData(
    inputDecorationTheme: input,
    textStyle: t.bodyMedium,
    menuStyle: MenuStyle(
      backgroundColor: WidgetStatePropertyAll<Color>(p.surfaceElevated),
      surfaceTintColor: _noOverlayTint,
      elevation: const WidgetStatePropertyAll<double>(0),
      shape: WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: AppRadius.controlRadius,
          side: BorderSide(color: p.border),
        ),
      ),
    ),
  );

  static const ButtonStyle _buttonBase = ButtonStyle(
    minimumSize: WidgetStatePropertyAll<Size>(Size(64, 48)),
    padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 20),
    ),
    shape: WidgetStatePropertyAll<OutlinedBorder>(_controlShape),
    elevation: WidgetStatePropertyAll<double>(0),
  );

  /// Primary and tonal buttons: shape and size only, colors come from the
  /// color scheme.
  static FilledButtonThemeData filledButton(TextStyle label) =>
      FilledButtonThemeData(
        style: _buttonBase.copyWith(
          textStyle: WidgetStatePropertyAll<TextStyle>(label),
        ),
      );

  /// Quiet neutral button.
  static ElevatedButtonThemeData elevatedButton(AppPalette p, TextStyle label) =>
      ElevatedButtonThemeData(
        style: _buttonBase.copyWith(
          textStyle: WidgetStatePropertyAll<TextStyle>(label),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (s) => s.contains(WidgetState.disabled) ? null : p.surfaceHigh,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (s) => s.contains(WidgetState.disabled) ? null : p.textPrimary,
          ),
          shadowColor: _noOverlayTint,
          surfaceTintColor: _noOverlayTint,
        ),
      );

  /// Secondary action with a visible border.
  static OutlinedButtonThemeData outlinedButton(
    AppPalette p,
    TextStyle label,
  ) => OutlinedButtonThemeData(
    style: _buttonBase.copyWith(
      textStyle: WidgetStatePropertyAll<TextStyle>(label),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>(
        (s) => s.contains(WidgetState.disabled) ? null : p.textPrimary,
      ),
      side: WidgetStateProperty.resolveWith<BorderSide?>(
        (s) => BorderSide(
          color: s.contains(WidgetState.disabled) ? p.border : p.borderStrong,
        ),
      ),
    ),
  );

  /// Tertiary action: brand-colored text that stays readable on dark.
  static TextButtonThemeData textButton(AppPalette p, TextStyle label) =>
      TextButtonThemeData(
        style: _buttonBase.copyWith(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(48, 44)),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: 12),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle>(label),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (s) => s.contains(WidgetState.disabled) ? null : p.primaryText,
          ),
        ),
      );

  /// Floating action button.
  static FloatingActionButtonThemeData fab(AppPalette p, TextStyle label) =>
      FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 3,
        highlightElevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.card)),
        ),
        extendedTextStyle: label,
      );

  /// Pill-shaped chips; the selected one fills with the brand container.
  static ChipThemeData chip(AppPalette p, TextTheme t) => ChipThemeData(
    backgroundColor: p.surfaceContainer,
    selectedColor: p.primaryContainer,
    disabledColor: p.surfaceContainer,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 0,
    pressElevation: 0,
    side: BorderSide(color: p.border),
    shape: const StadiumBorder(),
    labelStyle: t.labelLarge?.copyWith(
      color: p.textPrimary,
      fontWeight: FontWeight.w500,
    ),
    secondaryLabelStyle: t.labelLarge?.copyWith(
      color: p.textPrimary,
      fontWeight: FontWeight.w600,
    ),
    checkmarkColor: p.primaryText,
    iconTheme: IconThemeData(color: p.textSecondary, size: 18),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
  );

  /// Bottom navigation bar.
  static NavigationBarThemeData navigationBar(AppPalette p, TextTheme t) =>
      NavigationBarThemeData(
        backgroundColor: p.navBackground,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: p.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.nav)),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected)
                ? p.onPrimaryContainer
                : p.textSecondary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (s) => t.labelSmall?.copyWith(
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected)
                ? p.primaryText
                : p.textSecondary,
          ),
        ),
      );

  /// Side rail used on wide screens.
  static NavigationRailThemeData navigationRail(AppPalette p, TextTheme t) =>
      NavigationRailThemeData(
        backgroundColor: p.navBackground,
        elevation: 0,
        useIndicator: true,
        indicatorColor: p.primaryContainer,
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.nav)),
        ),
        selectedIconTheme: IconThemeData(color: p.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: p.textSecondary),
        selectedLabelTextStyle: t.labelMedium?.copyWith(color: p.primaryText),
        unselectedLabelTextStyle: t.labelMedium?.copyWith(
          color: p.textSecondary,
        ),
      );

  /// Dialogs.
  static DialogThemeData dialog(AppPalette p, TextTheme t) => DialogThemeData(
    backgroundColor: p.surfaceElevated,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.dialogRadius,
      side: BorderSide(color: p.border),
    ),
    titleTextStyle: t.titleLarge,
    contentTextStyle: t.bodyMedium?.copyWith(color: p.textSecondary),
  );

  /// Bottom sheets, with a drag handle.
  static BottomSheetThemeData bottomSheet(AppPalette p) => BottomSheetThemeData(
    backgroundColor: p.surfaceElevated,
    modalBackgroundColor: p.surfaceElevated,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    modalElevation: 0,
    clipBehavior: Clip.antiAlias,
    showDragHandle: true,
    dragHandleColor: p.borderStrong,
    dragHandleSize: const Size(40, 4),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetRadius),
  );

  /// Floating snackbars.
  static SnackBarThemeData snackBar(AppPalette p, TextTheme t) =>
      SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.inverseSurface,
        contentTextStyle: t.bodyMedium?.copyWith(color: p.onInverseSurface),
        actionTextColor: p.inversePrimary,
        closeIconColor: p.onInverseSurface,
        elevation: 0,
        shape: _controlShape,
      );

  /// Hairline divider.
  static DividerThemeData divider(AppPalette p) =>
      DividerThemeData(color: p.divider, thickness: 1, space: 1);

  /// List rows.
  static ListTileThemeData listTile(AppPalette p, TextTheme t) =>
      ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.textPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 8,
        titleTextStyle: t.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: t.bodyMedium?.copyWith(color: p.textSecondary),
        leadingAndTrailingTextStyle: t.bodyMedium?.copyWith(
          color: p.textSecondary,
        ),
        selectedColor: p.primaryText,
      );

  /// Expansion tiles without the default border lines.
  static ExpansionTileThemeData expansionTile(AppPalette p) =>
      ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: p.primaryText,
        collapsedIconColor: p.textSecondary,
        textColor: p.textPrimary,
        collapsedTextColor: p.textPrimary,
      );

  /// Switches.
  static SwitchThemeData switchTheme(AppPalette p) => SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith<Color?>((s) {
      if (s.contains(WidgetState.disabled)) {
        return p.textDisabled;
      }
      return s.contains(WidgetState.selected) ? p.onPrimary : p.textSecondary;
    }),
    trackColor: WidgetStateProperty.resolveWith<Color?>((s) {
      if (s.contains(WidgetState.disabled)) {
        return p.surfaceContainer;
      }
      return s.contains(WidgetState.selected) ? p.primary : p.surfaceHighest;
    }),
    trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
      (s) => s.contains(WidgetState.selected)
          ? Colors.transparent
          : (s.contains(WidgetState.disabled) ? p.border : p.borderStrong),
    ),
  );

  /// Checkboxes.
  static CheckboxThemeData checkbox(AppPalette p) => CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith<Color?>((s) {
      if (s.contains(WidgetState.disabled)) {
        return s.contains(WidgetState.selected) ? p.textDisabled : null;
      }
      return s.contains(WidgetState.selected) ? p.primary : Colors.transparent;
    }),
    checkColor: WidgetStatePropertyAll<Color>(p.onPrimary),
    side: WidgetStateBorderSide.resolveWith(
      (s) => s.contains(WidgetState.selected)
          ? BorderSide(color: p.primary, width: 2)
          : BorderSide(color: p.borderStrong, width: 1.5),
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(5)),
    ),
  );

  /// Radio buttons.
  static RadioThemeData radio(AppPalette p) => RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith<Color?>((s) {
      if (s.contains(WidgetState.disabled)) {
        return p.textDisabled;
      }
      return s.contains(WidgetState.selected) ? p.primaryText : p.borderStrong;
    }),
  );

  /// Segmented buttons (also used for the theme selector).
  static SegmentedButtonThemeData segmentedButton(AppPalette p, TextTheme t) =>
      SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 44)),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(_controlShape),
          textStyle: WidgetStatePropertyAll<TextStyle?>(t.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (s) =>
                s.contains(WidgetState.selected) ? p.primaryContainer : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((s) {
            if (s.contains(WidgetState.disabled)) {
              return p.textDisabled;
            }
            return s.contains(WidgetState.selected)
                ? p.onPrimaryContainer
                : p.textSecondary;
          }),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: p.borderStrong),
          ),
        ),
      );

  /// Progress bars and spinners.
  static ProgressIndicatorThemeData progress(AppPalette p) =>
      ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surfaceHighest,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
      );

  /// Tooltips.
  static TooltipThemeData tooltip(AppPalette p, TextTheme t) => TooltipThemeData(
    decoration: BoxDecoration(
      color: p.inverseSurface,
      borderRadius: AppRadius.smallRadius,
    ),
    textStyle: t.bodySmall?.copyWith(color: p.onInverseSurface),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  /// Overflow and popup menus.
  static PopupMenuThemeData popupMenu(AppPalette p, TextTheme t) =>
      PopupMenuThemeData(
        color: p.surfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: p.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.controlRadius,
          side: BorderSide(color: p.border),
        ),
        textStyle: t.bodyMedium,
      );

  /// Date picker dialog.
  static DatePickerThemeData datePicker(AppPalette p) => DatePickerThemeData(
    backgroundColor: p.surfaceElevated,
    surfaceTintColor: Colors.transparent,
    rangePickerBackgroundColor: p.surfaceElevated,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialogRadius),
  );

  /// Cursor and selection.
  static TextSelectionThemeData textSelection(AppPalette p) =>
      TextSelectionThemeData(
        cursorColor: p.primaryText,
        selectionColor: p.primary.withValues(alpha: 0.35),
        selectionHandleColor: p.primaryText,
      );
}
