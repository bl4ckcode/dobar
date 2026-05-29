class BarDetails {
  final int barId;
  final String barName;
  final String? description;
  final String? category;
  final String? address;
  final String? city;
  final String? state;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String? coverImageUrl;
  final String? logoUrl;
  final String? timezone;
  final String? createdAt;
  final String? updatedAt;

  BarDetails({
    required this.barId,
    required this.barName,
    this.description,
    this.category,
    this.address,
    this.city,
    this.state,
    this.country,
    this.latitude,
    this.longitude,
    this.coverImageUrl,
    this.logoUrl,
    this.timezone,
    this.createdAt,
    this.updatedAt,
  });

  factory BarDetails.fromJson(Map<String, dynamic> json) => BarDetails(
        barId: json['bar_id'] as int,
        barName: json['bar_name'] as String,
        description: json['description'] as String?,
        category: json['category'] as String?,
        address: json['address'] as String?,
        city: json['city'] as String?,
        state: json['state'] as String?,
        country: json['country'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        coverImageUrl: json['cover_image_url'] as String?,
        logoUrl: json['logo_url'] as String?,
        timezone: json['timezone'] as String?,
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'bar_name': barName,
        if (description != null) 'description': description,
        if (category != null) 'category': category,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
        if (logoUrl != null) 'logo_url': logoUrl,
      };
}
