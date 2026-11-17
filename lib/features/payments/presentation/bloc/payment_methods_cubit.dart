import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventrix/features/payments/domain/entities/payment_method.dart';
import 'package:inventrix/features/payments/domain/repositories/payment_method_repository.dart';
import 'package:inventrix/features/payments/domain/usecases/manage_payment_methods.dart';
import 'package:inventrix/features/settings/domain/repositories/preferences_repository.dart';
import 'package:inventrix/features/settings/domain/usecases/update_preferences.dart';
import 'package:inventrix/shared/presentation/view_status.dart';

/// State of the payment-methods screen.
final class PaymentMethodsState extends Equatable {
  /// Creates a state.
  const PaymentMethodsState({
    this.status = ViewStatus.initial,
    this.methods = const [],
    this.defaultMethodId,
    this.message,
  });

  /// Loading status.
  final ViewStatus status;

  /// Methods, archived ones included.
  final List<PaymentMethod> methods;

  /// Method preselected in payment and expense forms.
  final String? defaultMethodId;

  /// Message for the user (error or validation).
  final String? message;

  @override
  List<Object?> get props => [status, methods, defaultMethodId, message];
}

/// Lists, creates and archives payment methods.
class PaymentMethodsCubit extends Cubit<PaymentMethodsState> {
  /// Creates the cubit.
  PaymentMethodsCubit({
    required PaymentMethodRepository methods,
    required CreatePaymentMethod createMethod,
    required SetPaymentMethodArchived setArchived,
    PreferencesRepository? preferences,
    UpdatePreferences? updatePreferences,
  }) : _preferences = preferences,
       _updatePreferences = updatePreferences,
       _methods = methods,
       _create = createMethod,
       _setArchived = setArchived,
       super(const PaymentMethodsState());

  final PreferencesRepository? _preferences;
  final UpdatePreferences? _updatePreferences;
  final PaymentMethodRepository _methods;
  final CreatePaymentMethod _create;
  final SetPaymentMethodArchived _setArchived;

  /// Loads the list.
  Future<void> load({String? message}) async {
    emit(
      PaymentMethodsState(status: ViewStatus.loading, methods: state.methods),
    );
    final result = await _methods.list(includeArchived: true);
    final defaultId =
        (await _preferences?.load())?.valueOrNull?.defaultPaymentMethodId;
    if (isClosed) {
      return;
    }
    result.when(
      success: (list) => emit(
        PaymentMethodsState(
          status: list.isEmpty ? ViewStatus.empty : ViewStatus.loaded,
          methods: list,
          defaultMethodId: defaultId,
          message: message,
        ),
      ),
      failure: (failure) => emit(
        PaymentMethodsState(
          status: ViewStatus.failure,
          message: failure.userMessage,
        ),
      ),
    );
  }

  /// Creates a method; returns an error message, or `null` on success.
  Future<String?> create(String name) async {
    final failure = (await _create(name)).failureOrNull;
    if (failure != null) {
      return failure.userMessage;
    }
    await load();
    return null;
  }

  /// Archives or restores a method.
  Future<void> setArchived(String id, {required bool archived}) async {
    final failure = (await _setArchived(id, archived: archived)).failureOrNull;
    await load(message: failure?.userMessage);
  }

  /// Makes [id] the method preselected in payment and expense forms.
  Future<void> setDefault(String id) async {
    final update = _updatePreferences;
    if (update == null) {
      return;
    }
    final failure = (await update(
      (p) => p.copyWith(defaultPaymentMethodId: id),
    )).failureOrNull;
    await load(message: failure?.userMessage);
  }
}
