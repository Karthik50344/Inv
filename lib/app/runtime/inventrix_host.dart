import 'package:flutter/material.dart';
import 'package:inventrix/app/app.dart';
import 'package:inventrix/app/runtime/inventrix_runtime.dart';
import 'package:inventrix/app/runtime/startup_failure_app.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/core/constants/app_constants.dart';

/// Root widget: shows the app, a neutral "working" screen while a restore
/// replaces the data, or the start-up failure screen.
class InventrixHost extends StatefulWidget {
  /// Creates the host.
  const InventrixHost({required this.runtime, super.key});

  /// Source of truth for what to show.
  final InventrixRuntime runtime;

  @override
  State<InventrixHost> createState() => _InventrixHostState();
}

class _InventrixHostState extends State<InventrixHost> {
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();

  void _showPendingNotice() {
    final notice = widget.runtime.takeNotice();
    if (notice == null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messenger.currentState?.showSnackBar(
        SnackBar(
          content: Text(notice.message),
          duration: const Duration(seconds: 8),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.runtime,
      builder: (context, _) {
        final runtime = widget.runtime;
        switch (runtime.phase) {
          case RuntimePhase.running:
            _showPendingNotice();
            return InventrixApp(
              key: ValueKey(runtime.generation),
              router: runtime.router!,
              scaffoldMessengerKey: _messenger,
            );
          case RuntimePhase.failed:
            return const StartupFailureApp();
          case RuntimePhase.starting:
          case RuntimePhase.restarting:
            return MaterialApp(
              title: AppConstants.appName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              home: const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Applying backup… please wait.'),
                    ],
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}
