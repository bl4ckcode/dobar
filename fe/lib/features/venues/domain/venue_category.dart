/// Venue categories offered on Home. Route ids are stable URL segments;
/// [backendValue] is the `/bars?category=` filter (explicit, never derived).
enum VenueCategory {
  bars('bars', 'bar'),
  restaurants('restaurants', 'restaurant_bar'),
  clubs('clubs', 'night_club');

  final String routeId;
  final String backendValue;
  const VenueCategory(this.routeId, this.backendValue);

  static VenueCategory? fromRouteId(String? id) {
    for (final c in VenueCategory.values) {
      if (c.routeId == id) return c;
    }
    return null;
  }
}
