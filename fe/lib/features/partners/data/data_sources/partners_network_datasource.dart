import 'dart:async';
import 'package:dio/dio.dart';
import 'package:barz/core/network/api_response.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/core/network/api_config.dart';

import '../../domain/models/partner/partners_base_model.dart';
import '../../domain/models/partner/partners_params.dart';
import '../../domain/models/partner/partner_menu_model.dart';

class PartnersNetworkDataSource {
  final Dio dio;

  PartnersNetworkDataSource({required this.dio});

  // Existing method to get partners (adjusted as needed)
  Future<ApiResponse<List<PartnersBaseModel>>> getPartners(
    PartnersParams params,
  ) async {
    try {
      final response = await dio.get(
        '${baseUrl}bars/',
        queryParameters: {
          "latitude": params.latitude,
          "longitude": params.longitude,
          "max_distance": params.maxDistance,
        },
        options: Options(headers: getHeaders()),
      );

      if (response.statusCode == 200) {
        // Example: the API returns a list directly or under a key (e.g., "partners")
        List<dynamic> partnersJson;
        if (response.data is List) {
          partnersJson = response.data;
        } else if (response.data['partners'] is List) {
          partnersJson = response.data['partners'];
        } else {
          throw ServerException(
            'Unexpected response format',
            response.statusCode,
          );
        }
        final partnersList = partnersJson
            .map(
              (json) =>
                  PartnersBaseModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
        return ApiResponse.success(partnersList);
      } else {
        throw ServerException(
          'Failed to load partners: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        e.message ?? 'Dio error occurred',
        e.response?.statusCode,
      );
    } catch (e) {
      throw ServerException(e.toString(), null);
    }
  }

  // New method to fetch menus for a given bar id.
  Future<ApiResponse<List<PartnerMenu>>> getPartnerMenus(int barId) async {
    try {
      // The endpoint is constructed using the bar id.
      final response = await dio.get(
        '${baseUrl}menus/$barId',
        options: Options(headers: getHeaders()),
      );

      if (response.statusCode == 200) {
        // Assume the API returns a JSON list directly.
        List<dynamic> menusJson;
        if (response.data is List) {
          menusJson = response.data;
        } else if (response.data['menus'] is List) {
          menusJson = response.data['menus'];
        } else {
          throw ServerException(
            'Unexpected response format for menus',
            response.statusCode,
          );
        }

        final menus = menusJson
            .map((json) => PartnerMenu.fromJson(json as Map<String, dynamic>))
            .toList();
        return ApiResponse.success(menus);
      } else {
        throw ServerException(
          'Failed to load menus: ${response.statusCode}',
          response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw ServerException(
        e.message ?? 'Dio error occurred',
        e.response?.statusCode,
      );
    } catch (e) {
      throw ServerException(e.toString(), null);
    }
  }
}
