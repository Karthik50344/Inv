import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_dimensions.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';

/// The app bar of every screen: flat, centered title, optional subtitle.
///
/// The slot at the start holds, in order: the [leading] widget if given, the
/// back button (or drawer button) when Flutter would show one, and otherwise
/// the Inventrix symbol. On wide layouts the navigation rail already shows the
/// symbol, so the slot stays empty there.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Creates an app bar.
  const AppAppBar({
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.bottom,
    this.automaticallyImplyLeading = true,
    super.key,
  });

  /// Screen title.
  final String title;

  /// Small line under the title (for example a document number or period).
  final String? subtitle;

  /// Buttons at the end.
  final List<Widget>? actions;

  /// Widget at the start; replaces the back button and the logo.
  final Widget? leading;

  /// Widget under the bar (for example filter chips or a tab bar).
  final PreferredSizeWidget? bottom;

  /// Shows a back button when the screen can pop.
  final bool automaticallyImplyLeading;

  /// Whether Flutter will put a back or drawer button in the leading slot.
  bool _hasAutomaticLeading(BuildContext context) {
    if (!automaticallyImplyLeading) {
      return false;
    }
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && (scaffold.hasDrawer || scaffold.hasEndDrawer)) {
      return true;
    }
    return ModalRoute.of(context)?.canPop ?? false;
  }

  double get _toolbarHeight => subtitle == null ? kToolbarHeight : 64;

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showLogo =
        leading == null &&
            !_hasAutomaticLeading(context) &&
            MediaQuery.sizeOf(context).width < AppDimensions.wideLayoutBreakpoint;
    return AppBar(
      toolbarHeight: _toolbarHeight,
      centerTitle: true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: showLogo ? const _BrandMark() : leading,
      leadingWidth: showLogo ? 56 : null,
      actions: actions,
      bottom: bottom,
      title: subtitle == null
          ? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          dark
              ? 'assets/branding/inventrix_symbol_dark.png'
              : 'assets/branding/inventrix_symbol.png',
          width: 28,
          height: 28,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => const SizedBox(width: 28, height: 28),
        ),
      ),
    );
  }
}