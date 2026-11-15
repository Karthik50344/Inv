import 'package:equatable/equatable.dart';
import 'package:inventrix/shared/domain/value_objects/money.dart';
import 'package:inventrix/shared/domain/value_objects/quantity.dart';

/// A typed value in a report. The screen and the CSV export format it.
sealed class ReportCell extends Equatable {
  const ReportCell();

  @override
  List<Object?> get props => [];
}

/// Plain text.
final class TextCell extends ReportCell {
  /// Creates a cell.
  const TextCell(this.text);

  /// The text.
  final String text;

  @override
  List<Object?> get props => [text];
}

/// An amount of money.
final class MoneyCell extends ReportCell {
  /// Creates a cell.
  const MoneyCell(this.money);

  /// The amount.
  final Money money;

  @override
  List<Object?> get props => [money];
}

/// A quantity with the decimals its unit allows.
final class QuantityCell extends ReportCell {
  /// Creates a cell.
  const QuantityCell(this.quantity, {this.decimals = 3, this.unit = ''});

  /// The quantity.
  final Quantity quantity;

  /// Decimals to show.
  final int decimals;

  /// Unit symbol, may be empty.
  final String unit;

  @override
  List<Object?> get props => [quantity, decimals, unit];
}

/// A whole number such as a count.
final class CountCell extends ReportCell {
  /// Creates a cell.
  const CountCell(this.count);

  /// The number.
  final int count;

  @override
  List<Object?> get props => [count];
}

/// A calendar date.
final class DateCell extends ReportCell {
  /// Creates a cell.
  const DateCell(this.date);

  /// The date.
  final DateTime date;

  @override
  List<Object?> get props => [date];
}

/// A percentage given in basis points (100 = 1%).
final class PercentCell extends ReportCell {
  /// Creates a cell.
  const PercentCell(this.basisPoints);

  /// Basis points.
  final int basisPoints;

  @override
  List<Object?> get props => [basisPoints];
}

/// A value that does not apply (shown as a dash).
final class EmptyCell extends ReportCell {
  /// Creates the cell.
  const EmptyCell();
}

/// A headline figure of a report.
final class ReportMetric extends Equatable {
  /// Creates a metric.
  const ReportMetric(this.label, this.value, {this.hint});

  /// What the figure is.
  final String label;

  /// The figure.
  final ReportCell value;

  /// Optional short explanation shown under the figure.
  final String? hint;

  @override
  List<Object?> get props => [label, value, hint];
}

/// A column of a table.
final class ReportColumn extends Equatable {
  /// Creates a column.
  const ReportColumn(this.label, {this.numeric = false});

  /// Column heading.
  final String label;

  /// Whether the values are numbers (right aligned).
  final bool numeric;

  @override
  List<Object?> get props => [label, numeric];
}

/// A table of a report.
final class ReportTable extends Equatable {
  /// Creates a table.
  const ReportTable({
    required this.title,
    required this.columns,
    required this.rows,
    this.totalRowCount,
  });

  /// Heading above the table.
  final String title;

  /// Columns.
  final List<ReportColumn> columns;

  /// Rows; each has one cell per column.
  final List<List<ReportCell>> rows;

  /// Rows that exist in total, when [rows] holds only the newest ones.
  final int? totalRowCount;

  /// Whether [rows] is a subset of what exists.
  bool get isTruncated => totalRowCount != null && totalRowCount! > rows.length;

  @override
  List<Object?> get props => [title, columns, rows, totalRowCount];
}

/// One data series of a chart (amounts in minor units).
final class ChartSeries extends Equatable {
  /// Creates a series.
  const ChartSeries(this.name, this.values);

  /// Legend text.
  final String name;

  /// One value per label, in minor currency units.
  final List<int> values;

  @override
  List<Object?> get props => [name, values];
}

/// A bar chart over time.
final class ReportChart extends Equatable {
  /// Creates a chart.
  const ReportChart({
    required this.title,
    required this.labels,
    required this.series,
    required this.currencyCode,
    required this.decimalPlaces,
  });

  /// Heading above the chart.
  final String title;

  /// One label per bar group.
  final List<String> labels;

  /// The series; each has one value per label.
  final List<ChartSeries> series;

  /// Currency of the values.
  final String currencyCode;

  /// Decimals of the currency.
  final int decimalPlaces;

  /// Whether every value is zero.
  bool get isFlat => series.every((s) => s.values.every((v) => v == 0));

  @override
  List<Object?> get props => [
    title,
    labels,
    series,
    currencyCode,
    decimalPlaces,
  ];
}

/// Everything a report shows, independent of how it is drawn.
///
/// The same document feeds the screen and the CSV export, so what is
/// exported is always what was shown.
final class ReportDocument extends Equatable {
  /// Creates a document.
  const ReportDocument({
    required this.kind,
    required this.title,
    required this.generatedAt,
    this.periodText,
    this.scope = const [],
    this.metrics = const [],
    this.charts = const [],
    this.tables = const [],
    this.notes = const [],
  });

  /// Report type name (`ReportKind.name`), used for the file name.
  final String kind;

  /// Title.
  final String title;

  /// When the data was read.
  final DateTime generatedAt;

  /// The days covered, e.g. `2026-11-01 to 2026-11-15`; `null` for
  /// "as of now" reports.
  final String? periodText;

  /// Applied filters, e.g. `Customer: Acme`.
  final List<String> scope;

  /// Headline figures.
  final List<ReportMetric> metrics;

  /// Charts.
  final List<ReportChart> charts;

  /// Tables.
  final List<ReportTable> tables;

  /// Assumptions and caveats that apply to the figures.
  final List<String> notes;

  /// Whether the report has no tables rows, charts or non-zero data to show.
  bool get hasRows => tables.any((t) => t.rows.isNotEmpty);

  @override
  List<Object?> get props => [
    kind,
    title,
    generatedAt,
    periodText,
    scope,
    metrics,
    charts,
    tables,
    notes,
  ];
}
