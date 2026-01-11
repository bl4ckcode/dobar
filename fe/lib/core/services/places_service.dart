import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/dio_network.dart';

class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] as Map<String, dynamic>? ?? {};
    return PlacePrediction(
      placeId: json['place_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      mainText: structured['main_text'] as String? ?? '',
      secondaryText: structured['secondary_text'] as String? ?? '',
    );
  }
}

class ParsedPlaceDetails {
  final String placeId;
  final String name;
  final String address;
  final String? city;
  final String? state;
  final String? postalCode;
  final String countryCode;
  final double? latitude;
  final double? longitude;

  ParsedPlaceDetails({
    required this.placeId,
    required this.name,
    required this.address,
    this.city,
    this.state,
    this.postalCode,
    required this.countryCode,
    this.latitude,
    this.longitude,
  });

  factory ParsedPlaceDetails.fromJson(Map<String, dynamic> json) {
    return ParsedPlaceDetails(
      placeId: json['place_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      countryCode: json['country_code'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

class PlacesService {
  static Future<List<PlacePrediction>> autocomplete(
    String input, {
    List<String>? countries,
  }) async {
    if (input.trim().isEmpty) return [];

    try {
      final queryParams = <String, dynamic>{'input': input};
      if (countries != null && countries.isNotEmpty) {
        queryParams['countries'] = countries.join(',');
      }

      final response = await DioNetwork.appAPI.get(
        ApiEndpoints.placesAutocomplete,
        queryParameters: queryParams,
      );

      final data = response.data as Map<String, dynamic>;
      final predictions = data['predictions'] as List<dynamic>? ?? [];

      return predictions
          .map((p) => PlacePrediction.fromJson(p as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<ParsedPlaceDetails?> getDetails(String placeId) async {
    if (placeId.isEmpty) return null;

    try {
      final response = await DioNetwork.appAPI.get(
        ApiEndpoints.placesDetailsParsed,
        queryParameters: {'place_id': placeId},
      );

      return ParsedPlaceDetails.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }
}
