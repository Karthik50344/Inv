import 'package:equatable/equatable.dart';
import 'package:inventrix/features/reports/domain/entities/report_period.dart';
import 'package:inventrix/shared/domain/value_objects/date_range.dart';

/// Events of the dashboard.
sealed class DashboardEvent extends Equatable {
  const DashboardEvent();

  @override
  List<Object?> get props => [];
}

/// First load.
final class DashboardStarted extends DashboardEvent {
  /// Creates the event.
  const DashboardStarted();
}

/// Reload the current period (pull to refresh).
final class DashboardRefreshed extends DashboardEvent {
  /// Creates the event.
  const DashboardRefreshed();
}

/// A different period was chosen. [range] is required for the custom
/// period and ignored otherwise.
final class DashboardPeriodChanged extends DashboardEvent {
  /// Creates the event.
  const DashboardPeriodChanged(this.period, {this.range});

  /// The chosen period.
  final ReportPeriod period;

  /// The custom range.
  final DateRange? range;

  @override
  List<Object?> get props => [period, range];
}
