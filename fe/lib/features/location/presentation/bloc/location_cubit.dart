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
      final bool isServiceEnabled = serviceResult.fold(
        (_) => false,
        (enabled) => enabled,
      );
      if (!isServiceEnabled) {
        emit(
          state.copyWith(
            isLoading: false,
            error:
                'Location services disabled. Please enable them in Settings.',
          ),
        );
        return;
      }

      // 2. Permission check/request
      final permissionCheck = await _usecase.checkLocationPermission();
      bool hasPermission = permissionCheck.fold(
        (_) => false,
        (enabled) => enabled,
      );
      if (!hasPermission) {
        final permissionRequest = await _usecase.requestLocationPermission();
        hasPermission = permissionRequest.fold(
          (_) => false,
          (granted) => granted,
        );
        if (!hasPermission) {
          emit(
            state.copyWith(
              isLoading: false,
              hasPermission: false,
              error: 'Location permission required.',
            ),
          );
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
          emit(
            state.copyWith(
              isLoading: false,
              currentLocation: location,
              hasPermission: true,
              error: null,
            ),
          );
        },
      );
    } catch (e) {
      debugPrint('[LocationCubit] Fatal error: $e');
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Failed to obtain location. Please try again.',
        ),
      );
    }
  }

  /// Browsing never prompts. If the user already granted permission, pick up a
  /// fix silently so nearby discovery works; otherwise do nothing.
  Future<void> restoreIfGranted() async {
    if (state.isLoading || state.currentLocation != null) return;
    try {
      final service = await _usecase.checkLocationService();
      if (!service.fold((_) => false, (enabled) => enabled)) return;
      final permission = await _usecase.checkLocationPermission();
      if (!permission.fold((_) => false, (granted) => granted)) return;
    } catch (_) {
      return;
    }
    await getCurrentLocation();
  }

  /// Whether the OS permission is already granted (no prompt).
  Future<bool> hasPermissionNow() async {
    try {
      final permission = await _usecase.checkLocationPermission();
      final bool granted = permission.fold<bool>((_) => false, (g) => g);
      return granted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isPermanentlyDenied() async {
    try {
      final result = await _usecase.isLocationPermissionPermanentlyDenied();
      final bool denied = result.fold<bool>((_) => false, (d) => d);
      return denied;
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    await _usecase.openAppSettings();
  }
}
