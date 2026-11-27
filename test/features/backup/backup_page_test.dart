import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/core/constants/app_constants.dart';

import '../../support/widget_helpers.dart';
import '../../support/test_locator.dart';

/// Widget tests of the backup screen on top of the real router. (Written
/// without a Flutter SDK: not yet executed.)
void main() {
  testWidgets('Backup opens from More, shows the warning and empty history',
      (tester) async {
    final wiring = TestWiring();
    await pumpInventrix(tester, wiring, location: '/more/backup');
    expect(find.text('Backup & restore'), findsOneWidget);
    expect(find.text(AppConstants.localDataWarning), findsOneWidget);
    expect(find.byKey(const Key('backup-empty')), findsOneWidget);
    expect(find.byKey(const Key('backup-create')), findsOneWidget);
    expect(find.byKey(const Key('backup-restore-file')), findsOneWidget);
  });
}
