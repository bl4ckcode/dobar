import 'package:dio/dio.dart';
import '../../domain/models/home_model.dart';

import 'package:barz/core/api/api_endpoints.dart';

abstract class HomeDatasource {
  Future<HomeModel> getHomeData({double? latitude, double? longitude});
}

class HomeDatasourceImpl implements HomeDatasource {
  final Dio dio;

  HomeDatasourceImpl({required this.dio});

  @override
  Future<HomeModel> getHomeData({double? latitude, double? longitude}) async {
    final queryParams = <String, dynamic>{};
    if (latitude != null) queryParams['latitude'] = latitude;
    if (longitude != null) queryParams['longitude'] = longitude;

    final response = await dio.get(
      ApiEndpoints.home,
      queryParameters: queryParams,
    );
    return HomeModel.fromJson(response.data);
  }
}
