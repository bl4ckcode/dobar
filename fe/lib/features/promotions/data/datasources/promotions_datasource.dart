import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/promotions/domain/models/promotion_model.dart';
import 'package:barz/features/promotions/domain/models/offer_model.dart';
import 'package:dio/dio.dart';

abstract class PromotionsDatasource {
  /// Get promotions near user's location (location now required by backend)
  Future<List<PromotionModel>> getPromotions({
    required double latitude,
    required double longitude,
    double maxDistance = 5000,
    bool activeOnly = true,
  });
  Future<List<PromotionModel>> getPromotionsByDiscountType(PromoDiscountType type);
  Future<List<PromotionModel>> getPromotionsByBar(int barId, {bool activeOnly = true});
  Future<PromotionModel> getPromotionById(int id);
  Future<List<OfferModel>> getOffers();
  Future<List<OfferModel>> getOffersByPartnerId(int partnerId);
  Future<OfferModel> getOfferById(int id);
  Future<OfferModel> redeemOffer(int offerId);
}

class PromotionsNetworkDatasource implements PromotionsDatasource {
  final Dio dio;

  PromotionsNetworkDatasource({required this.dio});

  @override
  Future<List<PromotionModel>> getPromotions({
    required double latitude,
    required double longitude,
    double maxDistance = 5000,
    bool activeOnly = true,
  }) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.promotions}',
        queryParameters: {
          'latitude': latitude,
          'longitude': longitude,
          'max_distance': maxDistance,
          'active_only': activeOnly,
        },
      );
      return (response.data as List).map((json) => PromotionModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to get promotions', e.response?.statusCode);
    }
  }

  @override
  Future<List<PromotionModel>> getPromotionsByDiscountType(PromoDiscountType type) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.promotions}',
        queryParameters: {'discount_type': type.name},
      );
      return (response.data as List).map((json) => PromotionModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to get promotions by type', e.response?.statusCode);
    }
  }

  @override
  Future<List<PromotionModel>> getPromotionsByBar(int barId, {bool activeOnly = true}) async {
    try {
      final response = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.barPromotions(barId)}',
        queryParameters: {'active_only': activeOnly},
      );
      return (response.data as List).map((json) => PromotionModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to get bar promotions', e.response?.statusCode);
    }
  }

  @override
  Future<PromotionModel> getPromotionById(int id) async {
    try {
      final response = await dio.get('${ApiEndpoints.baseUrl}${ApiEndpoints.promotion(id)}');
      return PromotionModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to get promotion', e.response?.statusCode);
    }
  }

  @override
  Future<List<OfferModel>> getOffers() async {
    try {
      final response = await dio.get('${ApiEndpoints.baseUrl}${ApiEndpoints.offers}');
      return (response.data as List).map((json) => OfferModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to get offers', e.response?.statusCode);
    }
  }

  @override
  Future<List<OfferModel>> getOffersByPartnerId(int partnerId) async {
    try {
      final response = await dio.get('${ApiEndpoints.baseUrl}${ApiEndpoints.offers}', queryParameters: {'partner_id': partnerId});
      return (response.data as List).map((json) => OfferModel.fromJson(json)).toList();
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to get partner offers', e.response?.statusCode);
    }
  }

  @override
  Future<OfferModel> getOfferById(int id) async {
    try {
      final response = await dio.get('${ApiEndpoints.baseUrl}${ApiEndpoints.offers}/$id');
      return OfferModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to get offer', e.response?.statusCode);
    }
  }

  @override
  Future<OfferModel> redeemOffer(int offerId) async {
    try {
      final response = await dio.post('${ApiEndpoints.baseUrl}${ApiEndpoints.offers}/$offerId/redeem');
      return OfferModel.fromJson(response.data);
    } on DioException catch (e) {
      throw ServerException(e.response?.data?['detail'] ?? 'Failed to redeem offer', e.response?.statusCode);
    }
  }
}
