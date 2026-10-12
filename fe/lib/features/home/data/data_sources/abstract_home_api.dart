import 'package:barz/core/network/api_response.dart';
import 'package:barz/features/home/domain/models/home_model.dart';
import 'package:barz/features/home/domain/models/home_params.dart';

abstract class AbstractHomeApi {
  Future<ApiResponse<HomeModel>> getHome(HomeParams params);
}
