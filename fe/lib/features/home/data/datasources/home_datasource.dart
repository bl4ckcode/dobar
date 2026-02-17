import 'package:dio/dio.dart';
import '../../domain/models/home_model.dart';

import 'package:barz/core/api/api_endpoints.dart';

abstract class HomeDatasource {
  Future<HomeModel> getHomeData({double? lat, double? lng});
}

class HomeDatasourceImpl implements HomeDatasource {
  final Dio dio;

  HomeDatasourceImpl({required this.dio});

  @override
  Future<HomeModel> getHomeData({double? lat, double? lng}) async {
    final queryParams = <String, dynamic>{};
    if (lat != null) queryParams['lat'] = lat;
    if (lng != null) queryParams['lng'] = lng;

    final response = await dio.get(
      ApiEndpoints.home,
      queryParameters: queryParams,
    );
    return HomeModel.fromJson(response.data);
  }
}
