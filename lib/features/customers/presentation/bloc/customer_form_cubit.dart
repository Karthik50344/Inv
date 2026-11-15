import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/core/errors/failure.dart';
import 'package:inventrix/features/customers/domain/entities/customer.dart';
import 'package:inventrix/features/customers/domain/repositories/customer_repository.dart';
import 'package:inventrix/features/customers/domain/usecases/create_customer.dart';
import 'package:inventrix/features/customers/domain/usecases/update_customer.dart';
import 'package:inventrix/features/products/presentation/bloc/product_form_state.dart';
import 'package:inventrix/features/settings/domain/repositories/settings_repository.dart';
import 'package:inventrix/shared/domain/services/party_validation.dart';
import 'package:inventrix/shared/domain/value_objects/currency_config.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the customer form.
final class CustomerFormState extends Equatable {
  /// Creates a state.
  const CustomerFormState({
    this.loadStatus = FormLoadStatus.loading,
    this.submitStatus = SubmitStatus.idle,
    this.customer,
    this.currency,
    this.fieldErrors = const {},
    this.message,
    this.savedCustomerId,
  });

  /// Load status.
  final FormLoadStatus loadStatus;

  /// Submission status.
  final SubmitStatus submitStatus;

  /// The customer being edited, `null` when creating.
  final Customer? customer;

  /// Active currency (for labels and hints).
  final CurrencyConfig? currency;

  /// Per-field validation messages from the last submit.
  final Map<String, String> fieldErrors;

  /// One-shot user-facing message.
  final String? message;

  /// Id of the customer that was just saved.
  final String? savedCustomerId;

  /// Whether an existing customer is being edited.
  bool get isEditing => customer != null;

  /// Copy with changes. [fieldErrors], [message] and [savedCustomerId] reset
  /// unless provided.
  CustomerFormState copyWith({
    FormLoadStatus? loadStatus,
    SubmitStatus? submitStatus,
    Customer? customer,
    CurrencyConfig? currency,
    Map<String, String>? fieldErrors,
    String? message,
    String? savedCustomerId,
  }) => CustomerFormState(
    loadStatus: loadStatus ?? this.loadStatus,
    submitStatus: submitStatus ?? this.submitStatus,
    customer: customer ?? this.customer,
    currency: currency ?? this.currency,
    fieldErrors: fieldErrors ?? const {},
    message: message,
    savedCustomerId: savedCustomerId,
  );

  @override
  List<Object?> get props => [
    loadStatus,
    submitStatus,
    customer,
    currency,
    fieldErrors,
    message,
    savedCustomerId,
  ];
}

/// Drives the create/edit customer form.
class CustomerFormCubit extends Cubit<CustomerFormState> {
  /// Creates the cubit.
  CustomerFormCubit({
    required CustomerRepository repository,
    required SettingsRepository settings,
    required CreateCustomer createCustomer,
    required UpdateCustomer updateCustomer,
  }) : _repository = repository,
       _settings = settings,
       _create = createCustomer,
       _update = updateCustomer,
       super(const CustomerFormState());

  final CustomerRepository _repository;
  final SettingsRepository _settings;
  final CreateCustomer _create;
  final UpdateCustomer _update;

  /// Loads currency settings and, when [customerId] is given, the customer.
  Future<void> load({String? customerId}) async {
    emit(const CustomerFormState());
    Customer? existing;
    if (customerId != null) {
      final loaded = await _repository.getById(customerId);
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
        customer: existing,
        currency: currency.valueOrNull,
      ),
    );
  }

  /// Validates and saves the customer.
  Future<void> submit(PartyDraft draft) async {
    if (state.submitStatus == SubmitStatus.submitting) {
      return;
    }
    emit(state.copyWith(submitStatus: SubmitStatus.submitting));
    final existing = state.customer;
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
          customer: saved,
          savedCustomerId: saved.id,
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
