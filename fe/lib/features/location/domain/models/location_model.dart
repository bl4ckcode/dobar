class LocationModel {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final DateTime timestamp;

  LocationModel({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    required this.timestamp,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      timestamp: json['timestamp'] is String
          ? DateTime.parse(json['timestamp'])
          : DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  double distanceTo(LocationModel other) {
    const double earthRadius = 6371000;
    final dLat = _toRadians(other.latitude - latitude);
    final dLon = _toRadians(other.longitude - longitude);
    final a = _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_toRadians(latitude)) *
            _cos(_toRadians(other.latitude)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);
    final c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * 3.141592653589793 / 180;
  double _sin(double x) => _taylor(x, true);
  double _cos(double x) => _taylor(x, false);
  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }
  double _taylor(double x, bool isSin) {
    x = x % (2 * 3.141592653589793);
    if (x > 3.141592653589793) x -= 2 * 3.141592653589793;
    if (x < -3.141592653589793) x += 2 * 3.141592653589793;
    double result = isSin ? x : 1;
    double term = isSin ? x : 1;
    for (int n = 1; n <= 10; n++) {
      if (isSin) {
        term *= -x * x / ((2 * n) * (2 * n + 1));
      } else {
        term *= -x * x / ((2 * n - 1) * (2 * n));
      }
      result += term;
    }
    return result;
  }
  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.141592653589793;
    if (x < 0 && y < 0) return _atan(y / x) - 3.141592653589793;
    if (x == 0 && y > 0) return 3.141592653589793 / 2;
    if (x == 0 && y < 0) return -3.141592653589793 / 2;
    return 0;
  }
  double _atan(double x) {
    double result = 0;
    double term = x;
    for (int n = 0; n < 20; n++) {
      result += (n % 2 == 0 ? 1 : -1) * term / (2 * n + 1);
      term *= x * x;
    }
    return result;
  }
}
