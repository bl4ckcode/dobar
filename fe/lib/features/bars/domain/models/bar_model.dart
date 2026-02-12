class BarModel {
  final int id;
  final String name;
  final String address;
  final String phoneNumber;
  final String email;
  final int? ownerId;
  final String? imageUrl;
  final int? imageUrlExpiration; // Unix timestamp when presigned URL expires
  final String? logoUrl;
  final String? coverUrl;
  final List<String>? photoUrls;
  final double? approximateLocation;
  final double? latitude;
  final double? longitude;

  BarModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.email,
    this.ownerId,
    this.imageUrl,
    this.imageUrlExpiration,
    this.logoUrl,
    this.coverUrl,
    this.photoUrls,
    this.approximateLocation,
    this.latitude,
    this.longitude,
  });

  factory BarModel.fromJson(Map<String, dynamic> json) {
    return BarModel(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'] ?? '',
      ownerId: json['owner_id'],
      imageUrl: json['image_url'],
      imageUrlExpiration: json['image_url_expiration'],
      logoUrl: json['logo_url'],
      coverUrl: json['cover_url'],
      photoUrls: (json['photo_urls'] as List?)
          ?.map((e) => e as String)
          .toList(),
      approximateLocation: (json['approximateLocation'] != null)
          ? (json['approximateLocation'] as num).toDouble()
          : null,
      latitude: (json['latitude'] != null)
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: (json['longitude'] != null)
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }

  /// Creates a copy of this bar with an updated image URL
  BarModel copyWithImageUrl(String? newImageUrl, int? newExpiration) {
    return BarModel(
      id: id,
      name: name,
      address: address,
      phoneNumber: phoneNumber,
      email: email,
      ownerId: ownerId,
      imageUrl: newImageUrl,
      imageUrlExpiration: newExpiration,
      logoUrl: logoUrl,
      coverUrl: coverUrl,
      photoUrls: photoUrls,
      approximateLocation: approximateLocation,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone_number': phoneNumber,
      'email': email,
      'owner_id': ownerId,
      'image_url': imageUrl,
      'image_url_expiration': imageUrlExpiration,
      'logo_url': logoUrl,
      'cover_url': coverUrl,
      'photo_urls': photoUrls,
      'approximateLocation': approximateLocation,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
