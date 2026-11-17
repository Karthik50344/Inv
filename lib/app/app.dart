import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/core/constants/app_constants.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:inventrix/features/settings/presentation/bloc/settings_state.dart';
import 'package:inventrix/shared/domain/value_objects/display_formats.dart';

/// Root widget of Inventrix.
class InventrixApp extends StatelessWidget {
  /// Creates the app using [router] for navigation. When [settings] is
  /// given, the chosen theme is applied and every screen is redrawn when the
  /// date or number style changes.
  const InventrixApp({
    required this.router,
    this.settings,
    this.scaffoldMessengerKey,
    super.key,
  });

  /// Router configuration.
  final GoRouter router;

  /// Source of the theme and format preferences.
  final SettingsCubit? settings;

  /// Lets the host show a message after the app was rebuilt.
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  Widget build(BuildContext context) {
    final cubit = settings;
    if (cubit == null) {
      return _app(ThemeMode.system, null);
    }
    return BlocProvider<SettingsCubit>.value(
      value: cubit,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        buildWhen: (a, b) => a.preferences.theme != b.preferences.theme,
        builder: (context, state) =>
            _app(_themeMode(state.preferences.theme), cubit),
      ),
    );
  }

  Widget _app(ThemeMode mode, SettingsCubit? cubit) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: router,
      builder: cubit == null
          ? null
          : (context, child) => FormatRefresher(
              settings: cubit,
              child: child ?? const SizedBox.shrink(),
            ),
    );
  }

  static ThemeMode _themeMode(ThemePreference theme) => switch (theme) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };
}

/// Redraws every widget below it when the date or number style changes.
///
/// Screens format dates and money with `DateFormatter` and `MoneyFormatter`,
/// which read the active style when they run. After a change the existing
/// widgets must run `build` again; this marks them all dirty without
/// recreating them, so the navigation stack and form input stay as they are.
class FormatRefresher extends StatelessWidget {
  /// Creates the refresher.
  const FormatRefresher({
    required this.settings,
    required this.child,
    super.key,
  });

  /// Source of the styles.
  final SettingsCubit settings;

  /// The app below.
  final Widget child;

  static void _markDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markDirty);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsCubit, SettingsState>(
      bloc: settings,
      listenWhen: (a, b) =>
          a.preferences.dateStyle != b.preferences.dateStyle ||
          a.preferences.numberStyle != b.preferences.numberStyle ||
          a.status != b.status,
      listener: (context, _) => (context as Element).visitChildren(_markDirty),
      child: child,
    );
  }
}
