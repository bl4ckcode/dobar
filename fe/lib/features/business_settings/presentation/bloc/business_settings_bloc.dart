import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/business_settings/domain/usecases/business_settings_usecase.dart';
import 'package:barz/features/business_settings/presentation/bloc/business_settings_event.dart';
import 'package:barz/features/business_settings/presentation/bloc/business_settings_state.dart';

class BusinessSettingsBloc
    extends Bloc<BusinessSettingsEvent, BusinessSettingsState> {
  final BusinessSettingsUsecase _usecase;

  BusinessSettingsBloc(this._usecase) : super(const BusinessSettingsState()) {
    on<LoadBarDetails>(_onLoadBarDetails);
    on<UpdateBarDetails>(_onUpdateBarDetails);
    on<LoadContactSettings>(_onLoadContactSettings);
    on<UpdateContactSettings>(_onUpdateContactSettings);
    on<DeleteBusinessData>(_onDeleteBusinessData);
    on<DeactivateAccount>(_onDeactivateAccount);
    on<ReactivateAccount>(_onReactivateAccount);
    on<ClearError>(_onClearError);
  }

  Future<void> _onLoadBarDetails(
    LoadBarDetails event,
    Emitter<BusinessSettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getBarDetails(event.barId);
    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (barDetails) =>
          emit(state.copyWith(isLoading: false, barDetails: barDetails)),
    );
  }

  Future<void> _onUpdateBarDetails(
    UpdateBarDetails event,
    Emitter<BusinessSettingsState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.updateBarDetails(event.barId, event.data);
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (barDetails) => emit(
        state.copyWith(isProcessing: false, barDetails: barDetails),
      ),
    );
  }

  Future<void> _onLoadContactSettings(
    LoadContactSettings event,
    Emitter<BusinessSettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getContactSettings(event.barId);
    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (contactSettings) => emit(
        state.copyWith(isLoading: false, contactSettings: contactSettings),
      ),
    );
  }

  Future<void> _onUpdateContactSettings(
    UpdateContactSettings event,
    Emitter<BusinessSettingsState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result =
        await _usecase.updateContactSettings(event.barId, event.data);
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (contactSettings) => emit(
        state.copyWith(isProcessing: false, contactSettings: contactSettings),
      ),
    );
  }

  Future<void> _onDeleteBusinessData(
    DeleteBusinessData event,
    Emitter<BusinessSettingsState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.deleteBusinessData(event.barId);
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (deleteResult) => emit(
        state.copyWith(isProcessing: false, deleteResult: deleteResult),
      ),
    );
  }

  Future<void> _onDeactivateAccount(
    DeactivateAccount event,
    Emitter<BusinessSettingsState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.deactivateAccount(
      event.barId,
      reason: event.reason,
      estimatedReturnDate: event.estimatedReturnDate,
    );
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (deactivateResult) => emit(
        state.copyWith(isProcessing: false, deactivateResult: deactivateResult),
      ),
    );
  }

  Future<void> _onReactivateAccount(
    ReactivateAccount event,
    Emitter<BusinessSettingsState> emit,
  ) async {
    emit(state.copyWith(isProcessing: true, error: null));
    final result = await _usecase.reactivateAccount(event.barId);
    result.fold(
      (failure) => emit(
        state.copyWith(isProcessing: false, error: failure.errorMessage),
      ),
      (reactivateResult) => emit(
        state.copyWith(isProcessing: false, reactivateResult: reactivateResult),
      ),
    );
  }

  void _onClearError(ClearError event, Emitter<BusinessSettingsState> emit) {
    emit(state.copyWith(error: null));
  }
}
