class HomeParams {
  final double? latitude;
  final double? longitude;

  HomeParams({
    this.latitude,
    this.longitude,
  });

  factory HomeParams.fromJson(Map<String, dynamic> json) {
    return HomeParams(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
