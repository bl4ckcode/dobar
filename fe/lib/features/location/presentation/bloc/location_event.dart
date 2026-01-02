import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/location/domain/models/location_model.dart';

part 'location_event.freezed.dart';

@freezed
sealed class LocationEvent with _$LocationEvent {
  const factory LocationEvent.requestPermission() = RequestLocationPermission;
  const factory LocationEvent.checkPermission() = CheckLocationPermission;
  const factory LocationEvent.getCurrentLocation() = GetCurrentLocation;
  const factory LocationEvent.startTracking() = StartLocationTracking;
  const factory LocationEvent.stopTracking() = StopLocationTracking;
  const factory LocationEvent.locationUpdated(LocationModel location) = LocationUpdated;
  const factory LocationEvent.checkNearbyPartners() = CheckNearbyPartners;
  const factory LocationEvent.dismissProximityAlert() = DismissProximityAlert;
  const factory LocationEvent.clearError() = ClearLocationError;
}
