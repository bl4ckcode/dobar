import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:barz/features/location/domain/usecases/location_usecase.dart';
import 'location_state.dart';

class LocationCubit extends Cubit<LocationState> {
  final LocationUsecase _usecase;

  LocationCubit(this._usecase) : super(const LocationState());

  Future<void> getCurrentLocation() async {
    // Concurrency guard
    if (state.isLoading) {
      debugPrint('[LocationCubit] Already fetching location, ignoring request');
      return;
    }

    debugPrint('[LocationCubit] getCurrentLocation called');
    emit(state.copyWith(isLoading: true, error: null));

    try {
      // 1. Service check
      final serviceResult = await _usecase.checkLocationService();
      final bool isServiceEnabled = serviceResult.fold((_) => false, (enabled) => enabled);
      if (!isServiceEnabled) {
        emit(state.copyWith(isLoading: false, error: 'Location services disabled. Please enable them in Settings.'));
        return;
      }

      // 2. Permission check/request
      final permissionCheck = await _usecase.checkLocationPermission();
      bool hasPermission = permissionCheck.fold((_) => false, (enabled) => enabled);
      if (!hasPermission) {
        final permissionRequest = await _usecase.requestLocationPermission();
        hasPermission = permissionRequest.fold((_) => false, (granted) => granted);
        if (!hasPermission) {
          emit(state.copyWith(isLoading: false, hasPermission: false, error: 'Location permission required.'));
          return;
        }
      }

      // 3. Fetch location
      debugPrint('[LocationCubit] Requesting location fix...');
      final result = await _usecase.getCurrentLocation();
      result.fold(
        (failure) {
          debugPrint('[LocationCubit] Fetch failed: ${failure.errorMessage}');
          emit(state.copyWith(isLoading: false, error: failure.errorMessage));
        },
        (location) {
          debugPrint('[LocationCubit] Fetch success');
          emit(state.copyWith(isLoading: false, currentLocation: location, hasPermission: true, error: null));
        },
      );
    } catch (e) {
      debugPrint('[LocationCubit] Fatal error: $e');
      emit(state.copyWith(isLoading: false, error: 'Failed to obtain location. Please try again.'));
    }
  }

  Future<void> openSettings() async {
    await _usecase.openAppSettings();
  }
}
