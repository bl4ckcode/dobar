import 'package:barz/core/api/api_endpoints.dart';
import 'package:barz/core/network/api_response.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/home/data/data_sources/abstract_home_api.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/features/home/domain/models/home_params.dart';
import 'package:dio/dio.dart';

class HomeImplApi extends AbstractHomeApi {
  final Dio dio;

  HomeImplApi(this.dio);

  @override
  Future<ApiResponse<HomeModel>> getHome(HomeParams params) async {
    try {
      final queryParams = <String, dynamic>{};
      if (params.latitude != null) queryParams['latitude'] = params.latitude;
      if (params.longitude != null) queryParams['longitude'] = params.longitude;

      final result = await dio.get(
        '${ApiEndpoints.baseUrl}${ApiEndpoints.home}',
        queryParameters: queryParams,
      );
      if (result.data == null) {
        throw ServerException("Unknown Error", result.statusCode);
      }

      return ApiResponse.fromJson<HomeModel>(result.data);
    } on DioException catch (e) {
      throw ServerException(
        e.message ?? "Unknown error",
        e.response?.statusCode,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), null);
    }
  }
}
