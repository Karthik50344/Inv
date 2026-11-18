import 'package:flutter/material.dart';
import 'package:inventrix/shared/presentation/widgets/app_app_bar.dart';
import 'package:inventrix/shared/presentation/widgets/empty_state.dart';

/// Placeholder for features implemented in a later roadmap phase.
class ComingSoonPage extends StatelessWidget {
  /// Creates a placeholder for [title], planned for [phase].
  const ComingSoonPage({
    required this.title,
    required this.icon,
    required this.phase,
    super.key,
  });

  /// Feature name.
  final String title;

  /// Feature icon.
  final IconData icon;

  /// Roadmap phase that delivers the feature.
  final int phase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(title: title),
      body: EmptyState(
        icon: icon,
        title: title,
        message: 'This feature is planned for Phase $phase.',
      ),
    );
  }
}
