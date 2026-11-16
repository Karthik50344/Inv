import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/core/constants/app_constants.dart';

/// Root widget of Inventrix.
class InventrixApp extends StatelessWidget {
  /// Creates the app using [router] for navigation.
  const InventrixApp({
    required this.router,
    this.scaffoldMessengerKey,
    super.key,
  });

  /// Router configuration.
  final GoRouter router;

  /// Lets the host show a message after the app was rebuilt.
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      scaffoldMessengerKey: scaffoldMessengerKey,
      routerConfig: router,
    );
  }
}
