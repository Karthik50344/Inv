import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/services/clock.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_record.dart';
import 'package:inventrix/features/auditor_exports/domain/entities/export_request.dart';
import 'package:inventrix/features/auditor_exports/domain/usecases/generate_auditor_export.dart';
import 'package:inventrix/features/auditor_exports/presentation/support/export_preset.dart';

/// The steps of the export wizard.
enum ExportStep {
  /// Choose the period.
  period('Period'),

  /// Choose what to include.
  content('Content'),

  /// Choose the file type.
  format('File type'),

  /// Review and create.
  review('Review');

  const ExportStep(this.label);

  /// Name shown in the stepper.
  final String label;
}

/// State of the export wizard.
final class ExportWizardState extends Equatable {
  /// Creates the state.
  const ExportWizardState({
    required this.periodKind,
    required this.fyStartYear,
    required this.fyStartMonth,
    required this.datasets,
    required this.format,
    this.step = ExportStep.period,
    this.customFrom,
    this.customTo,
    this.name = '',
    this.submitting = false,
    this.record,
    this.error,
    this.periodError,
    this.contentError,
  });

  /// Current step.
  final ExportStep step;

  /// How the period is chosen.
  final ExportPeriodKind periodKind;

  /// Start year of the chosen financial year.
  final int fyStartYear;

  /// First month of the financial year (4 = April, 1 = calendar year).
  final int fyStartMonth;

  /// Custom range start.
  final DateTime? customFrom;

  /// Custom range end.
  final DateTime? customTo;

  /// What to include.
  final Set<ExportDataset> datasets;

  /// File type.
  final ExportFormat format;

  /// Optional name.
  final String name;

  /// Whether the export is being created.
  final bool submitting;

  /// The finished export.
  final ExportRecord? record;

  /// A readable error from creating the export.
  final String? error;

  /// A problem with the period.
  final String? periodError;

  /// A problem with the content choice.
  final String? contentError;

  /// The period as chosen, or `null` while a custom range is incomplete.
  ExportPeriod? get period {
    switch (periodKind) {
      case ExportPeriodKind.all:
        return const ExportPeriod.all();
      case ExportPeriodKind.financialYear:
        return ExportPeriod.financialYear(fyStartYear, startMonth: fyStartMonth);
      case ExportPeriodKind.custom:
        if (customFrom == null || customTo == null) {
          return null;
        }
        return ExportPeriod.custom(customFrom!, customTo!);
    }
  }

  /// The request the choices describe, or `null` while incomplete.
  ExportRequest? get request {
    final p = period;
    if (p == null || !p.isValid || datasets.isEmpty) {
      return null;
    }
    return ExportRequest(
      period: p,
      datasets: datasets,
      format: format,
      name: name.trim().isEmpty ? null : name.trim(),
    );
  }

  /// Copy with changes.
  ExportWizardState copyWith({
    ExportStep? step,
    ExportPeriodKind? periodKind,
    int? fyStartYear,
    int? fyStartMonth,
    DateTime? customFrom,
    DateTime? customTo,
    Set<ExportDataset>? datasets,
    ExportFormat? format,
    String? name,
    bool? submitting,
    ExportRecord? record,
    String? error,
    String? periodError,
    String? contentError,
    bool clearErrors = false,
  }) => ExportWizardState(
    step: step ?? this.step,
    periodKind: periodKind ?? this.periodKind,
    fyStartYear: fyStartYear ?? this.fyStartYear,
    fyStartMonth: fyStartMonth ?? this.fyStartMonth,
    customFrom: customFrom ?? this.customFrom,
    customTo: customTo ?? this.customTo,
    datasets: datasets ?? this.datasets,
    format: format ?? this.format,
    name: name ?? this.name,
    submitting: submitting ?? this.submitting,
    record: record ?? this.record,
    error: clearErrors ? null : error ?? this.error,
    periodError: clearErrors ? null : periodError ?? this.periodError,
    contentError: clearErrors ? null : contentError ?? this.contentError,
  );

  @override
  List<Object?> get props => [
    step,
    periodKind,
    fyStartYear,
    fyStartMonth,
    customFrom,
    customTo,
    datasets,
    format,
    name,
    submitting,
    record,
    error,
    periodError,
    contentError,
  ];
}

/// Drives the auditor export wizard.
class ExportWizardCubit extends Cubit<ExportWizardState> {
  /// Creates the cubit. [preset] pre-selects choices.
  ExportWizardCubit({
    required GenerateAuditorExport generate,
    required Clock clock,
    ExportPreset? preset,
  }) : _generate = generate,
       super(_initial(clock.now(), preset));

  final GenerateAuditorExport _generate;

  static ExportWizardState _initial(DateTime now, ExportPreset? preset) {
    // The financial year that contains today (April start).
    final year = now.month >= 4 ? now.year : now.year - 1;
    final hasRange = preset?.from != null && preset?.to != null;
    return ExportWizardState(
      periodKind: hasRange ? ExportPeriodKind.custom : ExportPeriodKind.financialYear,
      fyStartYear: year,
      fyStartMonth: 4,
      customFrom: preset?.from,
      customTo: preset?.to,
      datasets: preset?.datasets ?? {...ExportDataset.values}..remove(ExportDataset.invoicePdfs),
      format: preset?.format ?? ExportFormat.zip,
    );
  }

  /// Years offered for a financial year: the one chosen at the start and
  /// the four before it.
  late final List<int> fyYears = [
    for (var i = 0; i < 5; i++) state.fyStartYear - i,
  ];

  /// Chooses how the period is given.
  void setPeriodKind(ExportPeriodKind kind) =>
      emit(state.copyWith(periodKind: kind, clearErrors: true));

  /// Chooses the financial year.
  void setFyStartYear(int year) =>
      emit(state.copyWith(fyStartYear: year, clearErrors: true));

  /// Chooses April (4) or January (1) as the first month.
  void setFyStartMonth(int month) =>
      emit(state.copyWith(fyStartMonth: month, clearErrors: true));

  /// Sets the custom range.
  void setCustomRange(DateTime from, DateTime to) => emit(
    state.copyWith(customFrom: from, customTo: to, clearErrors: true),
  );

  /// Ticks or unticks one dataset.
  void toggleDataset(ExportDataset dataset, {required bool selected}) {
    final next = {...state.datasets};
    selected ? next.add(dataset) : next.remove(dataset);
    emit(state.copyWith(datasets: next, clearErrors: true));
  }

  /// Ticks everything except the (large) invoice PDFs.
  void selectAll() => emit(
    state.copyWith(
      datasets: {...ExportDataset.values}..remove(ExportDataset.invoicePdfs),
      clearErrors: true,
    ),
  );

  /// Unticks everything.
  void selectNone() => emit(state.copyWith(datasets: {}, clearErrors: true));

  /// Chooses the file type.
  void setFormat(ExportFormat format) =>
      emit(state.copyWith(format: format, clearErrors: true));

  /// Sets the export name.
  void setName(String name) => emit(state.copyWith(name: name));

  /// Goes back one step.
  void back() {
    if (state.step.index > 0 && !state.submitting) {
      emit(state.copyWith(step: ExportStep.values[state.step.index - 1], clearErrors: true));
    }
  }

  /// Moves on when the current step is complete.
  void next() {
    switch (state.step) {
      case ExportStep.period:
        final p = state.period;
        if (p == null) {
          emit(state.copyWith(periodError: 'Choose the first and last day.'));
          return;
        }
        if (!p.isValid) {
          emit(state.copyWith(periodError: 'The first day must not be after the last day.'));
          return;
        }
      case ExportStep.content:
        if (state.datasets.isEmpty) {
          emit(state.copyWith(contentError: 'Choose at least one thing to include.'));
          return;
        }
      case ExportStep.format:
      case ExportStep.review:
        break;
    }
    if (state.step.index < ExportStep.values.length - 1) {
      emit(state.copyWith(step: ExportStep.values[state.step.index + 1], clearErrors: true));
    }
  }

  /// Creates the export.
  Future<void> submit() async {
    final request = state.request;
    if (request == null || state.submitting) {
      return;
    }
    emit(state.copyWith(submitting: true, clearErrors: true));
    final result = await _generate(request);
    final record = result.valueOrNull;
    if (record == null) {
      emit(
        state.copyWith(
          submitting: false,
          error: result.failureOrNull?.message ?? 'The export could not be created.',
        ),
      );
      return;
    }
    emit(state.copyWith(submitting: false, record: record));
  }
}
