import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventrix/app/router/more_destinations.dart';
import 'package:inventrix/app/shell/more_page.dart';
import 'package:inventrix/app/theme/app_theme.dart';
import 'package:inventrix/core/formatters/date_formatter.dart';
import 'package:inventrix/shared/domain/enums/document_status.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/presentation/widgets/app_widgets.dart';
import 'package:inventrix/shared/presentation/widgets/search_field.dart';

final Map<String, ThemeData> _themes = {
  'light': AppTheme.light(),
  'dark': AppTheme.dark(),
};

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

Future<void> _pumpNarrow(WidgetTester tester, Widget app, {double w = 320}) async {
  tester.view
    ..physicalSize = Size(w, 700)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
}

void main() {
  group('AppButton', () {
    testWidgets('calls onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Save', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Save'));
      expect(taps, 1);
    });

    testWidgets('ignores taps and shows a spinner while loading', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton(label: 'Save', loading: true, onPressed: () => taps++)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Save'));
      expect(taps, 0);
    });

    testWidgets('is disabled without a callback', (tester) async {
      await tester.pumpWidget(
        _host(const AppButton(label: 'Save', onPressed: null)),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    for (final variant in AppButtonVariant.values) {
      for (final entry in _themes.entries) {
        testWidgets('${variant.name} renders in ${entry.key}', (tester) async {
          await tester.pumpWidget(
            _host(
              AppButton(
                label: 'Go',
                icon: Icons.add,
                variant: variant,
                onPressed: () {},
              ),
              theme: entry.value,
            ),
          );
          expect(find.text('Go'), findsOneWidget);
          expect(find.byIcon(Icons.add), findsOneWidget);
        });
      }
    }

    testWidgets('expand fills the width', (tester) async {
      await tester.pumpWidget(
        _host(AppButton(label: 'Wide', expand: true, onPressed: () {})),
      );
      expect(tester.getSize(find.byType(FilledButton)).width, 800);
    });
  });

  testWidgets('AppIconButton exposes its tooltip', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        AppIconButton(
          icon: Icons.edit,
          tooltip: 'Edit',
          showBadge: true,
          onPressed: () => taps++,
        ),
      ),
    );
    expect(find.byTooltip('Edit'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.edit));
    expect(taps, 1);
  });

  group('AppTextField', () {
    testWidgets('shows the validator message', (tester) async {
      final key = GlobalKey<FormState>();
      await tester.pumpWidget(
        _host(
          Form(
            key: key,
            child: AppTextField(
              label: 'Name',
              validator: (v) => (v ?? '').isEmpty ? 'Required' : null,
            ),
          ),
        ),
      );
      expect(key.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('reports edits', (tester) async {
      String? last;
      await tester.pumpWidget(
        _host(AppTextField(label: 'Name', onChanged: (v) => last = v)),
      );
      await tester.enterText(find.byType(TextFormField), 'Pen');
      expect(last, 'Pen');
    });
  });

  testWidgets('AppDropdown reports the chosen value', (tester) async {
    String? chosen;
    await tester.pumpWidget(
      _host(
        AppDropdown<String>(
          label: 'Unit',
          value: 'pcs',
          items: const [
            AppDropdownItem(value: 'pcs', label: 'Pieces'),
            AppDropdownItem(value: 'kg', label: 'Kilograms'),
          ],
          onChanged: (v) => chosen = v,
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kilograms').last);
    await tester.pumpAndSettle();
    expect(chosen, 'kg');
  });

  group('AppSearchField', () {
    testWidgets('shows a clear button once there is text', (tester) async {
      final seen = <String>[];
      await tester.pumpWidget(
        _host(AppSearchField(hintText: 'Search', onChanged: seen.add)),
      );
      expect(find.byTooltip('Clear search'), findsNothing);
      await tester.enterText(find.byType(TextField), 'pen');
      await tester.pump();
      expect(find.byTooltip('Clear search'), findsOneWidget);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(seen, ['pen', '']);
      expect(find.byTooltip('Clear search'), findsNothing);
    });

    testWidgets('legacy SearchField still works', (tester) async {
      String? text;
      await tester.pumpWidget(
        _host(SearchField(hintText: 'Find', onChanged: (v) => text = v)),
      );
      await tester.enterText(find.byType(TextField), 'abc');
      expect(text, 'abc');
    });

    testWidgets('renders the trailing widget', (tester) async {
      await tester.pumpWidget(
        _host(
          AppSearchField(
            hintText: 'Search',
            onChanged: (_) {},
            trailing: const Icon(Icons.tune),
          ),
        ),
      );
      expect(find.byIcon(Icons.tune), findsOneWidget);
    });
  });

  group('cards and badges', () {
    for (final entry in _themes.entries) {
      testWidgets('AppCard and AppStatCard render in ${entry.key}', (
        tester,
      ) async {
        var taps = 0;
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 200,
              child: AppStatCard(
                label: 'Total sales',
                value: '₹ 1,28,450.00',
                subtitle: 'vs last month',
                subtitleIcon: Icons.trending_up,
                icon: Icons.payments_outlined,
                tone: AppTone.success,
                onTap: () => taps++,
              ),
            ),
            theme: entry.value,
          ),
        );
        expect(find.text('Total sales'), findsOneWidget);
        expect(find.text('₹ 1,28,450.00'), findsOneWidget);
        expect(find.text('vs last month'), findsOneWidget);
        await tester.tap(find.text('Total sales'));
        expect(taps, 1);
      });
    }

    testWidgets('AppCard with a tone and selection builds', (tester) async {
      await tester.pumpWidget(
        _host(
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppCard(tone: AppTone.danger, child: Text('Alert')),
              AppCard(selected: true, child: Text('Chosen')),
            ],
          ),
        ),
      );
      expect(find.text('Alert'), findsOneWidget);
      expect(find.text('Chosen'), findsOneWidget);
    });

    testWidgets('AppStatCard does not overflow a long value', (tester) async {
      await _pumpNarrow(
        tester,
        _host(
          const SizedBox(
            width: 140,
            child: AppStatCard(
              label: 'A very long label for a tiny card',
              value: '₹ 123,456,789,012.00',
              subtitle: 'and a long supporting line as well',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('AppBadge shows every tone', (tester) async {
      await tester.pumpWidget(
        _host(
          Wrap(
            children: [
              for (final tone in AppTone.values)
                AppBadge(label: tone.name, tone: tone, icon: Icons.circle),
              const AppBadge(label: 'solid', solid: true, tone: AppTone.danger),
            ],
          ),
        ),
      );
      for (final tone in AppTone.values) {
        expect(find.text(tone.name), findsOneWidget);
      }
    });

    testWidgets('AppChip shows its count and reports selection', (
      tester,
    ) async {
      bool? selected;
      await tester.pumpWidget(
        _host(
          AppChip(
            label: 'Low stock',
            count: 8,
            selected: false,
            onSelected: (v) => selected = v,
          ),
        ),
      );
      expect(find.text('8'), findsOneWidget);
      await tester.tap(find.text('Low stock'));
      expect(selected, isTrue);
    });
  });

  testWidgets('AppSectionHeader fires its action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        AppSectionHeader(
          title: 'Recent invoices',
          subtitle: 'Last 7 days',
          actionLabel: 'View all',
          onAction: () => taps++,
        ),
      ),
    );
    expect(find.text('Recent invoices'), findsOneWidget);
    await tester.tap(find.text('View all'));
    expect(taps, 1);
  });

  testWidgets('AppAppBar shows title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          appBar: AppAppBar(title: 'INV-001', subtitle: 'Posted'),
        ),
      ),
    );
    expect(find.text('INV-001'), findsOneWidget);
    expect(find.text('Posted'), findsOneWidget);
  });

  testWidgets('AppFilterButton shows the active count', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(AppFilterButton(activeCount: 2, onPressed: () => taps++)),
    );
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.tune));
    expect(taps, 1);
  });

  group('AppCurrencyText', () {
    final money = Money.fromMinor(
      12345600,
      currencyCode: 'INR',
      decimalPlaces: 2,
    );

    testWidgets('formats with the number style, not a hardcoded symbol', (
      tester,
    ) async {
      await tester.pumpWidget(_host(AppCurrencyText(money)));
      final text = tester.widget<Text>(find.byType(Text)).data!;
      expect(text, contains('1,23,456.00'));
    });

    testWidgets('can hide the symbol and uses tabular figures', (tester) async {
      await tester.pumpWidget(
        _host(
          AppCurrencyText(
            money,
            showSymbol: false,
            size: AppCurrencySize.large,
          ),
        ),
      );
      final widget = tester.widget<Text>(find.byType(Text));
      expect(widget.data, '1,23,456.00');
      expect(
        widget.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });
  });

  group('AppDataTable', () {
    AppDataTable table() => AppDataTable(
      columns: const [
        AppDataColumn(label: 'Item', flex: 2),
        AppDataColumn(label: 'Qty', numeric: true),
        AppDataColumn(label: 'Price', numeric: true),
        AppDataColumn(label: 'Total', numeric: true),
      ],
      rows: [
        AppDataRow(
          cells: const [Text('Pen'), Text('3'), Text('10.00'), Text('30.00')],
          onTap: () {},
        ),
      ],
    );

    testWidgets('renders headings and rows', (tester) async {
      await _pumpNarrow(tester, _host(table()), w: 800);
      expect(find.text('Item'), findsOneWidget);
      expect(find.text('Pen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls instead of overflowing on a narrow screen', (
      tester,
    ) async {
      await _pumpNarrow(tester, _host(table()), w: 300);
      expect(tester.takeException(), isNull);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('shows the empty message', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppDataTable(
            columns: [AppDataColumn(label: 'A')],
            rows: [],
            emptyMessage: 'No lines',
          ),
        ),
      );
      expect(find.text('No lines'), findsOneWidget);
    });
  });

  group('states', () {
    for (final entry in _themes.entries) {
      testWidgets('empty, error and loading render in ${entry.key}', (
        tester,
      ) async {
        var retried = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: Scaffold(
              body: Column(
                children: [
                  const SizedBox(
                    height: 200,
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products yet',
                      message: 'Add your first product.',
                    ),
                  ),
                  SizedBox(
                    height: 200,
                    child: ErrorState(
                      message: 'Could not load',
                      onRetry: () => retried++,
                    ),
                  ),
                  const SizedBox(
                    height: 100,
                    child: LoadingIndicator(message: 'Loading'),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(find.text('No products yet'), findsOneWidget);
        expect(find.text('Loading'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        expect(retried, 1);
      });
    }

    testWidgets('aliases point at the same widgets', (tester) async {
      await tester.pumpWidget(
        _host(const AppEmptyState(icon: Icons.add, title: 'Nothing')),
      );
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('empty state survives a very short box', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(
            height: 80,
            child: EmptyState(
              icon: Icons.add,
              title: 'Nothing here',
              message: 'A longer explanation that needs space.',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('dialogs and sheets', () {
    Widget launcher(void Function(BuildContext) open) => _host(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('open'),
        ),
      ),
    );

    testWidgets('confirmation returns true on confirm', (tester) async {
      bool? result;
      await tester.pumpWidget(
        launcher((context) async {
          result = await showConfirmationDialog(
            context,
            title: 'Void invoice?',
            message: 'This cannot be undone.',
            confirmLabel: 'Void',
            destructive: true,
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Void invoice?'), findsOneWidget);
      await tester.tap(find.text('Void'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('confirmation returns false on cancel', (tester) async {
      bool? result;
      await tester.pumpWidget(
        launcher((context) async {
          result = await showConfirmationDialog(
            context,
            title: 'Delete?',
            message: 'Sure?',
          );
        }),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('bottom sheet shows its title and body', (tester) async {
      await tester.pumpWidget(
        launcher(
          (context) => showAppBottomSheet<void>(
            context: context,
            title: 'Filters',
            builder: (_) => const Text('Body'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Filters'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });

    testWidgets('showAppMessage shows success and error messages', (
      tester,
    ) async {
      await tester.pumpWidget(
        launcher(
          (context) =>
              showAppMessage(context, 'Saved', type: AppMessageType.success),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });
  });

  group('AppDatePickerField', () {
    testWidgets('shows the formatted date', (tester) async {
      final date = DateTime(2026, 11, 17);
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: AppDatePickerField(
              label: 'Date',
              value: date,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      expect(find.text(DateFormatter.date(date)), findsOneWidget);
    });

    testWidgets('opens the picker on tap', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: AppDatePickerField(
              label: 'Date',
              value: null,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('DocumentStatusChip', () {
    test('every status has a tone', () {
      for (final status in DocumentStatus.values) {
        expect(DocumentStatusChip.toneOf(status), isA<AppTone>());
      }
      expect(DocumentStatusChip.toneOf(DocumentStatus.posted), AppTone.success);
      expect(DocumentStatusChip.toneOf(DocumentStatus.voided), AppTone.danger);
      expect(DocumentStatusChip.toneOf(DocumentStatus.draft), AppTone.neutral);
    });

    testWidgets('keeps its key and label', (tester) async {
      await tester.pumpWidget(
        _host(const DocumentStatusChip(status: DocumentStatus.posted)),
      );
      expect(find.byKey(const Key('status_posted')), findsOneWidget);
      expect(find.text(DocumentStatus.posted.label), findsOneWidget);
    });
  });

  group('MorePage', () {
    for (final entry in _themes.entries) {
      testWidgets('lists every destination under its group in ${entry.key}', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(400, 1600)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(theme: entry.value, home: const MorePage()),
        );
        for (final group in MoreGroup.values) {
          expect(find.text(group.label), findsOneWidget);
        }
        for (final d in moreDestinations) {
          expect(find.text(d.title), findsOneWidget);
          expect(find.text(d.subtitle), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    test('every destination belongs to a group', () {
      for (final d in moreDestinations) {
        expect(MoreGroup.values, contains(d.group));
      }
    });
  });
}
