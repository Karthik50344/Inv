import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/suppliers/domain/entities/supplier.dart';
import 'package:inventrix/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:inventrix/features/suppliers/domain/usecases/create_supplier.dart';
import 'package:inventrix/features/suppliers/domain/usecases/update_supplier.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the supplier form.
final class SupplierFormState extends Equatable {
  /// Creates a state.
  const SupplierFormState({
    this.loadStatus = FormLoadStatus.loading,
    this.submitStatus = SubmitStatus.idle,
    this.supplier,
    this.currency,
    this.fieldErrors = const {},
    this.message,
    this.savedSupplierId,
  });

  /// Load status.
  final FormLoadStatus loadStatus;

  /// Submission status.
  final SubmitStatus submitStatus;

  /// The supplier being edited, `null` when creating.
  final Supplier? supplier;

  /// Active currency (for labels and hints).
  final CurrencyConfig? currency;

  /// Per-field validation messages from the last submit.
  final Map<String, String> fieldErrors;

  /// One-shot user-facing message.
  final String? message;

  /// Id of the supplier that was just saved.
  final String? savedSupplierId;

  /// Whether an existing supplier is being edited.
  bool get isEditing => supplier != null;

  /// Copy with changes. [fieldErrors], [message] and [savedSupplierId] reset
  /// unless provided.
  SupplierFormState copyWith({
    FormLoadStatus? loadStatus,
    SubmitStatus? submitStatus,
    Supplier? supplier,
    CurrencyConfig? currency,
    Map<String, String>? fieldErrors,
    String? message,
    String? savedSupplierId,
  }) => SupplierFormState(
    loadStatus: loadStatus ?? this.loadStatus,
    submitStatus: submitStatus ?? this.submitStatus,
    supplier: supplier ?? this.supplier,
    currency: currency ?? this.currency,
    fieldErrors: fieldErrors ?? const {},
    message: message,
    savedSupplierId: savedSupplierId,
  );

  @override
  List<Object?> get props => [
    loadStatus,
    submitStatus,
    supplier,
    currency,
    fieldErrors,
    message,
    savedSupplierId,
  ];
}

/// Drives the create/edit supplier form.
class SupplierFormCubit extends Cubit<SupplierFormState> {
  /// Creates the cubit.
  SupplierFormCubit({
    required SupplierRepository repository,
    required SettingsRepository settings,
    required CreateSupplier createSupplier,
    required UpdateSupplier updateSupplier,
  }) : _repository = repository,
       _settings = settings,
       _create = createSupplier,
       _update = updateSupplier,
       super(const SupplierFormState());

  final SupplierRepository _repository;
  final SettingsRepository _settings;
  final CreateSupplier _create;
  final UpdateSupplier _update;

  /// Loads currency settings and, when [supplierId] is given, the supplier.
  Future<void> load({String? supplierId}) async {
    emit(const SupplierFormState());
    Supplier? existing;
    if (supplierId != null) {
      final loaded = await _repository.getById(supplierId);
      existing = loaded.valueOrNull;
      if (existing == null) {
        final failure = loaded.failureOrNull!;
        emit(
          state.copyWith(
            loadStatus: failure is NotFoundFailure
                ? FormLoadStatus.notFound
                : FormLoadStatus.failure,
            message: failure.userMessage,
          ),
        );
        return;
      }
    }
    final currency = await _settings.getCurrencyConfig();
    if (currency.isFailure) {
      emit(
        state.copyWith(
          loadStatus: FormLoadStatus.failure,
          message: currency.failureOrNull!.userMessage,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        loadStatus: FormLoadStatus.ready,
        supplier: existing,
        currency: currency.valueOrNull,
      ),
    );
  }

  /// Validates and saves the supplier.
  Future<void> submit(PartyDraft draft) async {
    if (state.submitStatus == SubmitStatus.submitting) {
      return;
    }
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final existing = state.supplier;
    final result = existing == null
        ? await _create(draft)
        : await _update(existing.id, draft);
    if (isClosed) {
      return;
    }
    result.when(
      success: (saved) => emit(
        state.copyWith(
          submitStatus: SubmitStatus.success,
          supplier: saved,
          savedSupplierId: saved.id,
        ),
      ),
      failure: (failure) => emit(
        failure is ValidationFailure
            ? state.copyWith(
                submitStatus: SubmitStatus.validationError,
                fieldErrors: failure.fieldErrors,
                message: failure.fieldErrors.isEmpty ? failure.message : null,
              )
            : state.copyWith(
                submitStatus: SubmitStatus.failure,
                message: failure.userMessage,
              ),
      ),
    );
  }
}
