import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/bars/domain/usecases/bar_usecase.dart';
import 'package:barz/features/bars/domain/repositories/abstract_bar_repository.dart';
import 'package:barz/features/location/domain/usecases/location_usecase.dart';
import 'package:barz/features/session/presentation/bloc/session_bloc.dart';
import 'package:barz/features/session/presentation/bloc/session_state.dart';
import 'package:barz/features/checkin/domain/models/checkin_model.dart';
import 'package:barz/features/checkin/domain/repositories/checkin_repository.dart';
import 'checkin_event.dart';
import 'checkin_state.dart';

class CheckinBloc extends Bloc<CheckinEvent, CheckinState> {
  final BarUsecase barUsecase;
  final AbstractBarRepository bars;
  final CheckinRepository repository;
  final LocationUsecase location;
  final SessionBloc session;
  late final StreamSubscription<SessionState> sessionSubscription;
  int? _userId;

  CheckinBloc({
    required this.barUsecase,
    required this.bars,
    required this.repository,
    required this.location,
    required this.session,
  }) : super(const CheckinState()) {
    _userId = session.state.currentSession?.user.id;
    sessionSubscription = session.stream.listen((sessionState) {
      final userId = sessionState.currentSession?.user.id;
      if (userId != _userId) {
        _userId = userId;
        add(const ResetCheckin());
      }
    });
    on<LoadActiveCheckin>((event, emit) async {
      await _refresh(emit);
    });
    on<RefreshCheckin>((event, emit) async {
      final result = await _refresh(emit, barId: event.barId);
      event.completion.complete(result);
    });
    on<StartQrScan>(
      (event, emit) =>
          emit(state.copyWith(step: CheckinStep.scanning, clearError: true)),
    );
    on<QrCodeScanned>(_onQrCodeScanned);
    on<FindNearbyBars>(_onFindNearbyBars);
    on<SelectBar>(_onSelectBar);
    on<SetTableNumber>(
      (event, emit) => emit(state.copyWith(tableNumber: event.tableNumber)),
    );
    on<ConfirmCheckin>(_onConfirmCheckin);
    on<Checkout>((event, emit) async {
      try {
        await repository.end();
        emit(const CheckinState());
      } on CheckinException catch (error) {
        emit(state.copyWith(error: error.code));
      }
    });
    on<ClearCheckinError>(
      (event, emit) => emit(state.copyWith(clearError: true)),
    );
    on<ResetCheckin>((event, emit) => emit(const CheckinState()));
  }

  Future<bool> refresh({int? barId}) {
    final completion = Completer<bool>();
    add(RefreshCheckin(barId, completion));
    return completion.future;
  }

  Future<bool> _refresh(Emitter<CheckinState> emit, {int? barId}) async {
    final userId = session.state.currentSession?.user.id;
    if (userId == null) {
      emit(const CheckinState());
      return false;
    }
    try {
      final active = await repository.getActive();
      if (session.state.currentSession?.user.id != userId || isClosed) {
        return false;
      }
      final valid =
          active != null && active.userId == userId && active.isActive;
      emit(
        state.copyWith(
          activeCheckin: valid ? active : null,
          clearActiveCheckin: !valid,
          clearError: true,
        ),
      );
      return valid && (barId == null || active.barId == barId);
    } on CheckinException catch (error) {
      if (!isClosed) {
        emit(state.copyWith(clearActiveCheckin: true, error: error.code));
      }
      return false;
    }
  }

  Future<void> _onQrCodeScanned(
    QrCodeScanned event,
    Emitter<CheckinState> emit,
  ) async {
    try {
      final scan = QrScanResult.fromQrCode(event.qrCode);
      final result = await barUsecase.getBar(scan.barId);
      result.fold(
        (failure) => emit(state.copyWith(error: 'CHECKIN_INVALID_QR')),
        (bar) {
          emit(
            CheckinState(
              selectedBar: bar,
              tableNumber: scan.tableNumber,
              scanResult: scan,
              step: CheckinStep.confirmCheckin,
            ),
          );
          add(SelectBar(bar));
        },
      );
    } on FormatException {
      emit(state.copyWith(error: 'CHECKIN_INVALID_QR'));
    }
  }

  Future<void> _onFindNearbyBars(
    FindNearbyBars event,
    Emitter<CheckinState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        step: CheckinStep.nearbyBars,
        clearError: true,
      ),
    );
    final result = await barUsecase.getNearbyBars(
      event.latitude,
      event.longitude,
      5000,
    );
    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: 'NETWORK_ERROR')),
      (bars) => emit(state.copyWith(isLoading: false, nearbyBars: bars)),
    );
  }

  Future<void> _onSelectBar(SelectBar event, Emitter<CheckinState> emit) async {
    final sameBar = state.selectedBar?.id == event.bar.id;
    emit(
      CheckinState(
        selectedBar: event.bar,
        tableNumber: sameBar ? state.tableNumber : null,
        scanResult: sameBar ? state.scanResult : null,
        step: CheckinStep.confirmCheckin,
        isLoading: true,
      ),
    );
    final config = await bars.getLocationConfig(event.bar.id);
    config.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: 'NETWORK_ERROR')),
      (value) => emit(state.copyWith(isLoading: false, locationConfig: value)),
    );
  }

  Future<void> _onConfirmCheckin(
    ConfirmCheckin event,
    Emitter<CheckinState> emit,
  ) async {
    final bar = state.selectedBar;
    final userId = session.state.currentSession?.user.id;
    if (bar == null || userId == null) {
      emit(state.copyWith(error: 'UNAUTHORIZED'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      var allowed = (await location.checkLocationPermission()).fold(
        (_) => false,
        (value) => value,
      );
      if (!allowed) {
        allowed = (await location.requestLocationPermission()).fold(
          (_) => false,
          (value) => value,
        );
      }
      if (!allowed) throw const CheckinException('CHECKIN_LOCATION_REQUIRED');
      final fix = (await location.getCurrentLocation()).fold(
        (_) => null,
        (value) => value,
      );
      if (fix == null) {
        throw const CheckinException('CHECKIN_LOCATION_REQUIRED');
      }
      final checkin = await repository.confirm(
        barId: bar.id,
        location: fix,
        tableNumber: state.tableNumber,
      );
      if (session.state.currentSession?.user.id != userId) return;
      emit(
        state.copyWith(
          isLoading: false,
          activeCheckin: checkin,
          step: CheckinStep.checkedIn,
        ),
      );
    } on CheckinException catch (error) {
      emit(state.copyWith(isLoading: false, error: error.code));
    }
  }

  @override
  Future<void> close() async {
    await sessionSubscription.cancel();
    return super.close();
  }
}
