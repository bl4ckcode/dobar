import 'package:barz/core/network/api_response.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';

abstract class AbstractLoginApi {
  Future<ApiResponse<String?>> login(LoginParams params);
}