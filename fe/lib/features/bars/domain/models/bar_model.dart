class BarModel {
  final int id;
  final String name;
  final String address;
  final String phoneNumber;
  final String email;
  final int? ownerId;
  final String? imageUrl;
  final double? approximateLocation;

  BarModel({
    required this.id,
    required this.name,
    required this.address,
    required this.phoneNumber,
    required this.email,
    this.ownerId,
    this.imageUrl,
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
      approximateLocation: (json['approximateLocation'] != null)
          ? (json['approximateLocation'] as num).toDouble()
          : null,
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
      'approximateLocation': approximateLocation,
    };
  }
}
