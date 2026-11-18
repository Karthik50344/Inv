import 'package:flutter/material.dart';
import 'package:inventrix/app/theme/app_spacing.dart';
import 'package:inventrix/app/theme/app_theme_extensions.dart';
import 'package:inventrix/shared/presentation/widgets/app_card.dart';

/// A column of an [AppDataTable].
class AppDataColumn {
  /// Creates a column.
  const AppDataColumn({
    required this.label,
    this.flex = 1,
    this.minWidth = 96,
    this.numeric = false,
  });

  /// Heading text.
  final String label;

  /// Share of the free width when the table fits the screen.
  final int flex;

  /// Width used when the table is wider than the screen and scrolls.
  final double minWidth;

  /// Right-aligns the column (amounts, quantities).
  final bool numeric;
}

/// A row of an [AppDataTable]: one widget per column.
class AppDataRow {
  /// Creates a row.
  const AppDataRow({required this.cells, this.onTap});

  /// Cell contents, in column order.
  final List<Widget> cells;

  /// Called when the row is tapped.
  final VoidCallback? onTap;
}

/// A compact table for reports and ledgers.
///
/// It fills the screen width when the columns fit and scrolls horizontally
/// when they do not, so it never overflows on small phones.
class AppDataTable extends StatelessWidget {
  /// Creates the table.
  const AppDataTable({
    required this.columns,
    required this.rows,
    this.emptyMessage = 'Nothing to show',
    super.key,
  });

  /// Column definitions.
  final List<AppDataColumn> columns;

  /// Row data.
  final List<AppDataRow> rows;

  /// Shown instead of the rows when [rows] is empty.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needed = columns.fold<double>(
            0,
            (sum, c) => sum + c.minWidth,
          );
          final scrolls = constraints.maxWidth < needed;
          Widget line(List<Widget> cells, {VoidCallback? onTap, bool head = false}) {
            final row = Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: head ? AppSpacing.s8 : AppSpacing.s12,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < columns.length; i++)
                    _cell(columns[i], cells[i], scrolls),
                ],
              ),
            );
            final body = onTap == null
                ? row
                : InkWell(onTap: onTap, child: row);
            return head
                ? ColoredBox(color: colors.neutral.container, child: body)
                : body;
          }

          final tableWidth = scrolls ? needed + AppSpacing.s32 : null;
          final table = SizedBox(
            width: tableWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                line([
                  for (final c in columns)
                    Text(
                      c.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: c.numeric ? TextAlign.right : TextAlign.left,
                      style: context.appText.tableHeading,
                    ),
                ], head: true),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    child: Center(
                      child: Text(
                        emptyMessage,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(color: colors.divider),
                  line(rows[i].cells, onTap: rows[i].onTap),
                ],
              ],
            ),
          );
          return scrolls
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: table,
                )
              : table;
        },
      ),
    );
  }

  Widget _cell(AppDataColumn column, Widget cell, bool scrolls) {
    final aligned = Align(
      alignment: column.numeric
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: cell,
    );
    return scrolls
        ? SizedBox(width: column.minWidth, child: aligned)
        : Expanded(flex: column.flex, child: aligned);
  }
}
