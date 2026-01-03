class BarModel {
  final int id;
  final String name;
  final String address;
  final String phoneNumber;
  final String email;
  final int? ownerId;
  final String? imageUrl;
  final int? imageUrlExpiration; // Unix timestamp when presigned URL expires
  final double? approximateLocation;

  BarModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.email,
    this.ownerId,
    this.imageUrl,
    this.imageUrlExpiration,
    this.approximateLocation,
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
      approximateLocation: (json['approximateLocation'] != null)
          ? (json['approximateLocation'] as num).toDouble()
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
      approximateLocation: approximateLocation,
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
      'approximateLocation': approximateLocation,
    };
  }
}
