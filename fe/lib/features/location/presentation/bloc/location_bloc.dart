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
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.errorMessage)),
      (granted) =>
          emit(state.copyWith(isLoading: false, hasPermission: granted)),
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

    // First check if location services are enabled
    final serviceResult = await _usecase.checkLocationService();
    final serviceEnabled = await serviceResult.fold(
      (_) async => false,
      (enabled) async => enabled,
    );

    if (!serviceEnabled) {
      final serviceRequestResult = await _usecase.requestLocationService();
      final serviceGranted = await serviceRequestResult.fold(
        (_) async => false,
        (enabled) async => enabled,
      );

      if (!serviceGranted) {
        emit(
          state.copyWith(
            isLoading: false,
            error:
                'Location services are disabled. Please enable location services in Settings > Privacy & Security > Location Services.',
          ),
        );
        return;
      }
    }

    // Ensure we have permission before reading location.
    // On iOS especially, calling getLocation() without permission can fail silently
    // or return nulls, which prevents the app from loading nearby content.
    final permissionResult = await _usecase.checkLocationPermission();
    final hasPermission = await permissionResult.fold(
      (_) async => false,
      (granted) async => granted,
    );

    if (!hasPermission) {
      final requestResult = await _usecase.requestLocationPermission();
      final granted = await requestResult.fold(
        (_) async => false,
        (granted) async => granted,
      );

      emit(state.copyWith(hasPermission: granted));

      if (!granted) {
        emit(
          state.copyWith(
            isLoading: false,
            error: 'Location permission is required to show nearby bars.',
          ),
        );
        return;
      }
    } else {
      emit(state.copyWith(hasPermission: true));
    }

    final result = await _usecase.getCurrentLocation();
    result.fold(
      (failure) {
        // Provide fallback to Belo Horizonte coordinates for development
        final fallbackLocation = LocationModel(
          latitude: -19.8325619,
          longitude: -43.9798416,
          accuracy: 1000.0,
          altitude: 0.0,
          speed: 0.0,
          timestamp: DateTime.now(),
        );
        emit(
          state.copyWith(
            isLoading: false,
            currentLocation: fallbackLocation,
            error:
                'Using default Belo Horizonte location (location unavailable)',
          ),
        );
      },
      (location) {
        emit(
          state.copyWith(
            isLoading: false,
            currentLocation: location,
            error: null,
          ),
        );
      },
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
    result.fold((failure) => {}, (partners) {
      final withinRange = partners.where((p) => p.isWithinRange).toList();
      emit(
        state.copyWith(
          nearbyPartners: partners,
          proximityAlert: withinRange.isNotEmpty ? withinRange.first : null,
        ),
      );
    });
  }

  void _onDismissProximityAlert(
    DismissProximityAlert event,
    Emitter<LocationState> emit,
  ) {
    emit(state.copyWith(proximityAlert: null));
  }

  void _onClearError(ClearLocationError event, Emitter<LocationState> emit) {
    emit(state.copyWith(error: null));
  }
}
