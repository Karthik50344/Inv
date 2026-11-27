import 'package:material_ui/material_ui.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/core/constants/app_constants.dart';

/// Shown when the database cannot be opened or migrated.
class StartupFailureApp extends StatelessWidget {
  /// Creates the recovery screen.
  const StartupFailureApp({this.message, super.key});

  /// Specific, user-safe explanation (for example a missing encryption
  /// key); a generic text is shown when `null`.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              message ??
                  "${AppConstants.appName} couldn't open its database. "
                      'No data has been deleted or reset. Please restart the '
                      'app; if the problem continues, contact support before '
                      'reinstalling.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
