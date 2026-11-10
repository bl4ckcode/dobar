import 'venue_list_item.dart';

abstract class VenueRepository {
  /// Throws on failure; callers decide how to surface it.
  Future<VenuePage> fetch(VenueQuery query);
}
