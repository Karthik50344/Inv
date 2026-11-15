import 'package:equatable/equatable.dart';
import 'package:inventrix/features/reports/domain/entities/report_filter.dart';
import 'package:inventrix/features/reports/domain/entities/report_kind.dart';
import 'package:inventrix/features/reports/domain/entities/report_period.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';

/// Events of a report screen.
sealed class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

/// Open a report with the default period.
final class ReportStarted extends ReportEvent {
  /// Creates the event.
  const ReportStarted(this.kind);

  /// The report to open.
  final ReportKind kind;

  @override
  List<Object?> get props => [kind];
}

/// A different period was chosen. [range] is required for the custom
/// period and ignored otherwise.
final class ReportPeriodChanged extends ReportEvent {
  /// Creates the event.
  const ReportPeriodChanged(this.period, {this.range});

  /// The chosen period.
  final ReportPeriod period;

  /// The custom range.
  final DateRange? range;

  @override
  List<Object?> get props => [period, range];
}

/// The product, customer or supplier filter changed.
final class ReportFilterChanged extends ReportEvent {
  /// Creates the event with the complete new filter.
  const ReportFilterChanged(this.filter);

  /// The new filter (its range is kept as is).
  final ReportFilter filter;

  @override
  List<Object?> get props => [filter];
}

/// Reload the current report.
final class ReportRefreshed extends ReportEvent {
  /// Creates the event.
  const ReportRefreshed();
}

/// Share the current report as a CSV file.
final class ReportExportRequested extends ReportEvent {
  /// Creates the event.
  const ReportExportRequested();
}
