import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/route_paths.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';

/// Shown when a route or record cannot be found.
class NotFoundPage extends StatelessWidget {
  /// Creates the page for the unknown [location].
  const NotFoundPage({required this.location, super.key});

  /// The location that could not be resolved.
  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: EmptyState(
        icon: Icons.search_off,
        title: 'Page not found',
        message: "We couldn't find $location.",
        action: FilledButton(
          onPressed: () => context.go(RoutePaths.dashboard),
          child: const Text('Go to dashboard'),
        ),
      ),
    );
  }
}
