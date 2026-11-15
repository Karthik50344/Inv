import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventrix/app/router/more_destinations.dart';

/// Entry point for secondary sections.
class MorePage extends StatelessWidget {
  /// Creates the page.
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          for (final destination in moreDestinations)
            ListTile(
              leading: Icon(destination.icon),
              title: Text(destination.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.goNamed(destination.name),
            ),
        ],
      ),
    );
  }
}
