import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/bars/domain/usecases/bar_usecase.dart';
import 'package:barz/features/checkin/domain/models/checkin_model.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_event.dart';
import 'package:barz/features/checkin/presentation/bloc/checkin_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// BLoC for managing check-in flow
class CheckinBloc extends Bloc<CheckinEvent, CheckinState> {
  final BarUsecase _barUsecase;
  final SharedPreferences _prefs;

  static const String _activeCheckinKey = 'active_checkin';

  CheckinBloc({
    required BarUsecase barUsecase,
    required SharedPreferences prefs,
  }) : _barUsecase = barUsecase,
       _prefs = prefs,
       super(const CheckinState()) {
    on<LoadActiveCheckin>(_onLoadActiveCheckin);
    on<StartQrScan>(_onStartQrScan);
    on<QrCodeScanned>(_onQrCodeScanned);
    on<FindNearbyBars>(_onFindNearbyBars);
    on<SelectBar>(_onSelectBar);
    on<SetTableNumber>(_onSetTableNumber);
    on<ConfirmCheckin>(_onConfirmCheckin);
    on<Checkout>(_onCheckout);
    on<ClearCheckinError>(_onClearError);
    on<ResetCheckin>(_onReset);
  }

  Future<void> _onLoadActiveCheckin(
    LoadActiveCheckin event,
    Emitter<CheckinState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    // Load from local storage
    final checkinJson = _prefs.getString(_activeCheckinKey);
    if (checkinJson != null) {
      try {
        final checkin = CheckinModel.fromJson(jsonDecode(checkinJson));
        if (checkin.isActive) {
          emit(
            state.copyWith(
              isLoading: false,
              activeCheckin: checkin,
              step: CheckinStep.checkedIn,
            ),
          );
          return;
        }
      } catch (_) {
        // Invalid stored data, clear it
        await _prefs.remove(_activeCheckinKey);
      }
    }

    emit(state.copyWith(isLoading: false, step: CheckinStep.initial));
  }

  void _onStartQrScan(StartQrScan event, Emitter<CheckinState> emit) {
    emit(state.copyWith(step: CheckinStep.scanning, clearError: true));
  }

  Future<void> _onQrCodeScanned(
    QrCodeScanned event,
    Emitter<CheckinState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final scanResult = QrScanResult.fromQrCode(event.qrCode);

      // Fetch bar details
      final result = await _barUsecase.getBar(scanResult.barId);

      result.fold(
        (failure) =>
            emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
        (bar) => emit(
          state.copyWith(
            isLoading: false,
            scanResult: scanResult,
            selectedBar: bar,
            tableNumber: scanResult.tableNumber,
            step: CheckinStep.confirmCheckin,
          ),
        ),
      );
    } on FormatException catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Invalid QR code: ${e.message}',
        ),
      );
    }
  }

  Future<void> _onFindNearbyBars(
    FindNearbyBars event,
    Emitter<CheckinState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, step: CheckinStep.nearbyBars));

    // Search within 100 meters for check-in
    final result = await _barUsecase.getNearbyBars(
      event.latitude,
      event.longitude,
      5000.0, // 5km
    );

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (bars) => emit(state.copyWith(isLoading: false, nearbyBars: bars)),
    );
  }

  void _onSelectBar(SelectBar event, Emitter<CheckinState> emit) {
    emit(
      state.copyWith(selectedBar: event.bar, step: CheckinStep.confirmCheckin),
    );
  }

  void _onSetTableNumber(SetTableNumber event, Emitter<CheckinState> emit) {
    emit(state.copyWith(tableNumber: event.tableNumber));
  }

  Future<void> _onConfirmCheckin(
    ConfirmCheckin event,
    Emitter<CheckinState> emit,
  ) async {
    if (state.selectedBar == null) {
      emit(state.copyWith(error: 'No bar selected'));
      return;
    }

    emit(state.copyWith(isLoading: true));

    // Create local check-in (backend integration would go here)
    final checkin = CheckinModel(
      id: DateTime.now().millisecondsSinceEpoch,
      userId: 0, // Would come from auth
      barId: state.selectedBar!.id,
      barName: state.selectedBar!.name,
      barImageUrl: state.selectedBar!.imageUrl,
      tableNumber: state.tableNumber,
      status: CheckinStatus.active,
      checkedInAt: DateTime.now(),
    );

    // Store locally
    await _prefs.setString(_activeCheckinKey, jsonEncode(checkin.toJson()));

    emit(
      state.copyWith(
        isLoading: false,
        activeCheckin: checkin,
        step: CheckinStep.checkedIn,
      ),
    );
  }

  Future<void> _onCheckout(Checkout event, Emitter<CheckinState> emit) async {
    if (state.activeCheckin == null) return;

    emit(state.copyWith(isLoading: true));

    // Clear local storage
    await _prefs.remove(_activeCheckinKey);

    emit(
      state.copyWith(
        isLoading: false,
        clearActiveCheckin: true,
        step: CheckinStep.initial,
      ),
    );
  }

  void _onClearError(ClearCheckinError event, Emitter<CheckinState> emit) {
    emit(state.copyWith(clearError: true));
  }

  void _onReset(ResetCheckin event, Emitter<CheckinState> emit) {
    emit(const CheckinState());
  }
}
