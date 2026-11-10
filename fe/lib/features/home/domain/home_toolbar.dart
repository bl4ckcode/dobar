import 'package:barz/features/home/domain/models/home_model.dart';

/// Distance (metres) the nearest venue must be strictly below for the
/// check-in prompt to take over the toolbar.
const double kNearbyCheckinThresholdMeters = 10;

sealed class HomeToolbarContent {
  const HomeToolbarContent();
}

/// "Você está perto de {venue}" – opens the existing check-in flow.
class NearbyVenueToolbar extends HomeToolbarContent {
  final NearestVenue venue;
  const NearbyVenueToolbar(this.venue);
}

/// "Olá, {name}, você tem {N} promos".
class PromoGreetingToolbar extends HomeToolbarContent {
  final String? name;
  final int count;
  const PromoGreetingToolbar({this.name, required this.count});
}

class PlainGreetingToolbar extends HomeToolbarContent {
  final String? name;
  const PlainGreetingToolbar({this.name});
}

/// Toolbar precedence: nearby venue (< 10 m, known distance) → promo count
/// (> 0) → plain greeting. Unknown/absent summary data yields the greeting.
HomeToolbarContent resolveHomeToolbar(HomeModel? data) {
  if (data == null) return const PlainGreetingToolbar();
  final nearest = data.nearestVenue;
  final distance = nearest?.distanceMeters;
  if (nearest != null &&
      nearest.id != 0 &&
      distance != null &&
      distance < kNearbyCheckinThresholdMeters) {
    return NearbyVenueToolbar(nearest);
  }
  final count = data.promoSummary?.total ?? 0;
  if (count > 0) {
    return PromoGreetingToolbar(name: data.displayName, count: count);
  }
  return PlainGreetingToolbar(name: data.displayName);
}

/// `null` => hide the badge; capped at `99+`.
String? notificationBadgeLabel(int count) {
  if (count <= 0) return null;
  return count > 99 ? '99+' : '$count';
}
