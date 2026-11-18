import 'package:flutter/material.dart';

/// Visual weight of an [AppButton].
enum AppButtonVariant {
  /// The one main action of a screen.
  primary,

  /// A quieter filled action (brand tint).
  secondary,

  /// An action with a visible border.
  outlined,

  /// A low-emphasis text action.
  text,

  /// A destructive action (delete, void).
  destructive,
}

/// Height of an [AppButton].
enum AppButtonSize {
  /// 48 logical pixels; the default touch target.
  medium(48),

  /// 40 logical pixels, for dense rows and cards.
  small(40);

  const AppButtonSize(this.height);

  /// Minimum height.
  final double height;
}

/// The one button of the app: pick a [variant], never style a raw button.
///
/// While [loading] the button keeps its look, shows a spinner and ignores
/// taps, so a double tap cannot submit twice.
class AppButton extends StatelessWidget {
  /// Creates a button.
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.loading = false,
    this.expand = false,
    super.key,
  });

  /// Text of the button.
  final String label;

  /// Called on tap; null disables the button.
  final VoidCallback? onPressed;

  /// Optional leading icon.
  final IconData? icon;

  /// Visual weight.
  final AppButtonVariant variant;

  /// Height.
  final AppButtonSize size;

  /// Shows a spinner and ignores taps.
  final bool loading;

  /// Fills the available width.
  final bool expand;

  static void _ignore() {}

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final VoidCallback? callback = onPressed == null
        ? null
        : (loading ? _ignore : onPressed);
    final leading = loading
        ? const _Spinner()
        : (icon == null ? null : Icon(icon, size: 20));
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll<Size>(Size(0, size.height)),
      backgroundColor: variant == AppButtonVariant.destructive
          ? WidgetStateProperty.resolveWith<Color?>(
              (s) => s.contains(WidgetState.disabled) ? null : scheme.error,
            )
          : null,
      foregroundColor: variant == AppButtonVariant.destructive
          ? WidgetStateProperty.resolveWith<Color?>(
              (s) => s.contains(WidgetState.disabled) ? null : scheme.onError,
            )
          : null,
    );
    final Widget button = switch (variant) {
      AppButtonVariant.primary || AppButtonVariant.destructive =>
        leading == null
            ? FilledButton(onPressed: callback, style: style, child: text)
            : FilledButton.icon(
                onPressed: callback,
                style: style,
                icon: leading,
                label: text,
              ),
      AppButtonVariant.secondary =>
        leading == null
            ? FilledButton.tonal(onPressed: callback, style: style, child: text)
            : FilledButton.tonalIcon(
                onPressed: callback,
                style: style,
                icon: leading,
                label: text,
              ),
      AppButtonVariant.outlined =>
        leading == null
            ? OutlinedButton(onPressed: callback, style: style, child: text)
            : OutlinedButton.icon(
                onPressed: callback,
                style: style,
                icon: leading,
                label: text,
              ),
      AppButtonVariant.text =>
        leading == null
            ? TextButton(onPressed: callback, style: style, child: text)
            : TextButton.icon(
                onPressed: callback,
                style: style,
                icon: leading,
                label: text,
              ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(
      strokeWidth: 2.2,
      color: DefaultTextStyle.of(context).style.color,
    ),
  );
}
