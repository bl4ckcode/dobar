import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/usecases/location_usecase.dart';
import 'package:barz/features/location/presentation/bloc/location_event.dart';
import 'package:barz/features/location/presentation/bloc/location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final LocationUsecase _usecase;
  StreamSubscription<LocationModel>? _locationSubscription;

  LocationBloc(this._usecase) : super(const LocationState()) {
    on<RequestLocationPermission>(_onRequestPermission);
    on<CheckLocationPermission>(_onCheckPermission);
    on<GetCurrentLocation>(_onGetCurrentLocation);
    on<StartLocationTracking>(_onStartTracking);
    on<StopLocationTracking>(_onStopTracking);
    on<LocationUpdated>(_onLocationUpdated);
    on<CheckNearbyPartners>(_onCheckNearbyPartners);
    on<DismissProximityAlert>(_onDismissProximityAlert);
    on<ClearLocationError>(_onClearError);
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    return super.close();
  }

  Future<void> _onRequestPermission(
    RequestLocationPermission event,
    Emitter<LocationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.requestLocationPermission();
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (granted) => emit(state.copyWith(isLoading: false, hasPermission: granted)),
    );
  }

  Future<void> _onCheckPermission(
    CheckLocationPermission event,
    Emitter<LocationState> emit,
  ) async {
    final result = await _usecase.checkLocationPermission();
    result.fold(
      (failure) => emit(state.copyWith(error: failure.errorMessage)),
      (granted) => emit(state.copyWith(hasPermission: granted)),
    );
  }

  Future<void> _onGetCurrentLocation(
    GetCurrentLocation event,
    Emitter<LocationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    final result = await _usecase.getCurrentLocation();
    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (location) => emit(state.copyWith(isLoading: false, currentLocation: location)),
    );
  }

  void _onStartTracking(
    StartLocationTracking event,
    Emitter<LocationState> emit,
  ) {
    _locationSubscription?.cancel();
    _locationSubscription = _usecase.getLocationStream().listen(
          (location) => add(LocationUpdated(location)),
        );
    emit(state.copyWith(isTracking: true));
  }

  void _onStopTracking(
    StopLocationTracking event,
    Emitter<LocationState> emit,
  ) {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    emit(state.copyWith(isTracking: false));
  }

  Future<void> _onLocationUpdated(
    LocationUpdated event,
    Emitter<LocationState> emit,
  ) async {
    emit(state.copyWith(currentLocation: event.location));
    add(const CheckNearbyPartners());
  }

  Future<void> _onCheckNearbyPartners(
    CheckNearbyPartners event,
    Emitter<LocationState> emit,
  ) async {
    if (state.currentLocation == null) return;
    final result = await _usecase.getNearbyPartners(state.currentLocation!);
    result.fold(
      (failure) => {},
      (partners) {
        final withinRange = partners.where((p) => p.isWithinRange).toList();
        emit(state.copyWith(
          nearbyPartners: partners,
          proximityAlert: withinRange.isNotEmpty ? withinRange.first : null,
        ));
      },
    );
  }

  void _onDismissProximityAlert(
    DismissProximityAlert event,
    Emitter<LocationState> emit,
  ) {
    emit(state.copyWith(proximityAlert: null));
  }

  void _onClearError(
    ClearLocationError event,
    Emitter<LocationState> emit,
  ) {
    emit(state.copyWith(error: null));
  }
}
