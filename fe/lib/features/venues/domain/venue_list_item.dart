/// A venue row from `GET /bars` in listing mode.
class VenueListItem {
  final int id;
  final String name;
  final double rating;
  final double? distanceMeters; // null without location
  final String? imageUrl;
  final String? category;

  /// `happy_hour` | `cashback` | `promotion` | null (backend classification).
  final String? primaryPromotion;
  final String? promotionText;

  const VenueListItem({
    required this.id,
    required this.name,
    this.rating = 0,
    this.distanceMeters,
    this.imageUrl,
    this.category,
    this.primaryPromotion,
    this.promotionText,
  });

  factory VenueListItem.fromJson(Map<String, dynamic> json) => VenueListItem(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    distanceMeters: (json['approximateLocation'] as num?)?.toDouble(),
    imageUrl: (json['image_url'] ?? json['logo_url']) as String?,
    category: json['category'] as String?,
    primaryPromotion: json['primary_promotion'] as String?,
    promotionText: json['promotion_text'] as String?,
  );
}

class VenuePage {
  final List<VenueListItem> items;
  final int total;
  final bool hasMore;
  const VenuePage({
    required this.items,
    required this.total,
    required this.hasMore,
  });
}

class VenueQuery {
  final String category; // backend value
  final double? latitude;
  final double? longitude;
  final String search;
  final double? minRating;
  final bool promosOnly;
  final int? maxDistanceKm; // only meaningful with a location
  final int offset;
  final int limit;

  const VenueQuery({
    required this.category,
    this.latitude,
    this.longitude,
    this.search = '',
    this.minRating,
    this.promosOnly = false,
    this.maxDistanceKm,
    this.offset = 0,
    this.limit = 20,
  });

  bool get hasLocation => latitude != null && longitude != null;

  VenueQuery copyWith({int? offset}) => VenueQuery(
    category: category,
    latitude: latitude,
    longitude: longitude,
    search: search,
    minRating: minRating,
    promosOnly: promosOnly,
    maxDistanceKm: maxDistanceKm,
    offset: offset ?? this.offset,
    limit: limit,
  );

  Map<String, dynamic> toQueryParameters() => {
    'category': category,
    'limit': limit,
    'offset': offset,
    if (hasLocation) 'latitude': latitude,
    if (hasLocation) 'longitude': longitude,
    if (hasLocation && maxDistanceKm != null)
      'max_distance': (maxDistanceKm! * 1000).toDouble(),
    if (search.trim().isNotEmpty) 'q': search.trim(),
    if (minRating != null && minRating! > 0) 'min_rating': minRating,
    if (promosOnly) 'has_promotions': true,
  };
}
