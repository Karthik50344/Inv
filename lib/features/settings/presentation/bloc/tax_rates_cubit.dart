import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/result/result.dart';
import 'package:inventrix/features/settings/domain/entities/tax_rate.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/features/settings/domain/repositories/tax_rate_repository.dart';
import 'package:inventrix/features/settings/domain/usecases/create_tax_rate.dart';
import 'package:inventrix/features/settings/domain/usecases/manage_tax_rates.dart';
import 'package:inventrix/features/settings/domain/usecases/update_preferences.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the tax rates screen.
final class TaxRatesState extends Equatable {
  /// Creates a state.
  const TaxRatesState({
    this.status = ViewStatus.initial,
    this.rates = const [],
    this.defaultRateId,
    this.defaultPriceIncludesTax = false,
    this.message,
    this.messageSerial = 0,
  });

  /// Loading status.
  final ViewStatus status;

  /// Rates, archived ones included.
  final List<TaxRate> rates;

  /// Rate preselected for new products.
  final String? defaultRateId;

  /// Whether new products start with tax-inclusive prices.
  final bool defaultPriceIncludesTax;

  /// Message for the user.
  final String? message;

  /// Incremented with every message.
  final int messageSerial;

  /// Copy with changes.
  TaxRatesState copyWith({
    ViewStatus? status,
    List<TaxRate>? rates,
    String? defaultRateId,
    bool clearDefault = false,
    bool? defaultPriceIncludesTax,
    String? message,
  }) => TaxRatesState(
    status: status ?? this.status,
    rates: rates ?? this.rates,
    defaultRateId: clearDefault ? null : defaultRateId ?? this.defaultRateId,
    defaultPriceIncludesTax:
        defaultPriceIncludesTax ?? this.defaultPriceIncludesTax,
    message: message,
    messageSerial: message == null ? messageSerial : messageSerial + 1,
  );

  @override
  List<Object?> get props => [
    status,
    rates,
    defaultRateId,
    defaultPriceIncludesTax,
    message,
    messageSerial,
  ];
}

/// Lists, creates, edits and archives tax rates and chooses the defaults
/// for new products.
class TaxRatesCubit extends Cubit<TaxRatesState> {
  /// Creates the cubit.
  TaxRatesCubit({
    required TaxRateRepository taxRates,
    required PreferencesRepository preferences,
    required CreateTaxRate createTaxRate,
    required UpdateTaxRate updateTaxRate,
    required SetTaxRateArchived setArchived,
    required SetDefaultTaxRate setDefault,
    required UpdatePreferences updatePreferences,
  }) : _taxRates = taxRates,
       _preferences = preferences,
       _create = createTaxRate,
       _update = updateTaxRate,
       _setArchived = setArchived,
       _setDefault = setDefault,
       _updatePreferences = updatePreferences,
       super(const TaxRatesState());

  final TaxRateRepository _taxRates;
  final PreferencesRepository _preferences;
  final CreateTaxRate _create;
  final UpdateTaxRate _update;
  final SetTaxRateArchived _setArchived;
  final SetDefaultTaxRate _setDefault;
  final UpdatePreferences _updatePreferences;

  /// Loads rates and defaults.
  Future<void> load({String? message}) async {
    final rates = await _taxRates.list(includeArchived: true);
    final preferences = await _preferences.load();
    if (isClosed) {
      return;
    }
    final failure = rates.failureOrNull ?? preferences.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      );
      return;
    }
    final list = rates.valueOrNull!;
    final prefs = preferences.valueOrNull!;
    emit(
      TaxRatesState(
        status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
        rates: list,
        defaultRateId: prefs.defaultTaxRateId,
        defaultPriceIncludesTax: prefs.defaultPriceIncludesTax,
        message: message,
        messageSerial: message == null
            ? state.messageSerial
            : state.messageSerial + 1,
      ),
    );
  }

  /// Creates a rate; the dialog shows field errors from the result.
  Future<Result<TaxRate>> create({
    required String name,
    required String ratePercent,
    required bool isExempt,
  }) async {
    final result = await _create(
      name: name,
      ratePercent: ratePercent,
      isExempt: isExempt,
    );
    if (result.isSuccess) {
      await load(message: 'Tax rate added.');
    }
    return result;
  }

  /// Updates the rate [id]; the dialog shows field errors from the result.
  Future<Result<TaxRate>> update({
    required String id,
    required String name,
    required String ratePercent,
    required bool isExempt,
  }) async {
    final result = await _update(
      id: id,
      name: name,
      ratePercent: ratePercent,
      isExempt: isExempt,
    );
    if (result.isSuccess) {
      await load(message: 'Tax rate saved.');
    }
    return result;
  }

  /// Archives or restores a rate.
  Future<void> setArchived(String id, {required bool archived}) async {
    final result = await _setArchived(id, archived: archived);
    if (isClosed) {
      return;
    }
    if (result.isFailure) {
      emit(state.copyWith(message: result.failureOrNull!.userMessage));
      return;
    }
    await load(message: archived ? 'Tax rate archived.' : 'Tax rate restored.');
  }

  /// Makes [id] the rate preselected for new products; `null` clears it.
  Future<void> setDefault(String? id) async {
    final result = await _setDefault(id);
    if (isClosed) {
      return;
    }
    if (result.isFailure) {
      emit(state.copyWith(message: result.failureOrNull!.userMessage));
      return;
    }
    await load();
  }

  /// Chooses whether new products start with tax-inclusive prices.
  Future<void> setDefaultPriceIncludesTax({required bool value}) async {
    final result = await _updatePreferences(
      (p) => p.copyWith(defaultPriceIncludesTax: value),
    );
    if (isClosed) {
      return;
    }
    if (result.isFailure) {
      emit(state.copyWith(message: result.failureOrNull!.userMessage));
      return;
    }
    emit(state.copyWith(defaultPriceIncludesTax: value));
  }
}
