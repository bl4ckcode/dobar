import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:barz/features/location/domain/models/location_model.dart';
import 'package:barz/features/location/domain/models/partner_proximity.dart';

part 'location_state.freezed.dart';

@freezed
class LocationState with _$LocationState {
  const factory LocationState({
    LocationModel? currentLocation,
    @Default([]) List<PartnerProximity> nearbyPartners,
    PartnerProximity? proximityAlert,
    @Default(false) bool isLoading,
    @Default(false) bool hasPermission,
    @Default(false) bool isTracking,
    String? error,
  }) = _LocationState;
}
