import 'package:inventrix/core/formatters/money_formatter.dart';
import 'package:inventrix/features/reports/domain/entities/report_document.dart';
import 'package:intl/intl.dart';

/// Formats [ReportCell]s and dates for the screen.
abstract final class ReportFormatters {
  static const MoneyFormatter _money = MoneyFormatter();

  /// `15 Nov 2026`.
  static String day(DateTime date) => DateFormat('d MMM y').format(date);

  /// `1 Nov 2026 – 15 Nov 2026`.
  static String range(DateTime from, DateTime to) =>
      '${day(from)} – ${day(to)}';

  /// Text for one cell.
  static String cell(ReportCell cell) => switch (cell) {
    TextCell(:final text) => text,
    MoneyCell(:final money) => _money.format(money),
    QuantityCell(:final quantity, :final decimals, :final unit) =>
      unit.isEmpty
          ? quantity.toFixedString(decimals)
          : '${quantity.toFixedString(decimals)} $unit',
    CountCell(:final count) => '$count',
    DateCell(:final date) => day(date),
    PercentCell(:final basisPoints) => percent(basisPoints),
    EmptyCell() => '–',
  };

  /// `12.34%` for 1234 basis points.
  static String percent(int basisPoints) {
    final sign = basisPoints < 0 ? '-' : '';
    final abs = basisPoints.abs();
    return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}%';
  }

  /// Whether a cell holds a negative amount or percentage.
  static bool isNegative(ReportCell cell) => switch (cell) {
    MoneyCell(:final money) => money.isNegative,
    PercentCell(:final basisPoints) => basisPoints < 0,
    _ => false,
  };
}
