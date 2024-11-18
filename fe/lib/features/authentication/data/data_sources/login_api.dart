import 'package:barz/core/network/api_config.dart';
import 'package:barz/core/network/api_response.dart';
import 'package:barz/core/network/exceptions.dart';
import 'package:barz/features/authentication/data/data_sources/abstract_login_api.dart';
import 'package:barz/features/authentication/domain/models/login_params.dart';
import 'package:dio/dio.dart';

class LoginApi extends AbstractLoginApi {
  final Dio dio;

  LoginApi(this.dio);

  @override
  Future<ApiResponse<String?>> login(LoginParams params) async {
    try {
      final response = await dio.post(
        "$baseUrl/auth/sms/send", // Your backend endpoint for sending SMS
        data: {
          'phone_number': params.phoneNumber,
        },
        options: Options(headers: getHeaders()),
      );

      if (response.data == null) {
        throw ServerException("Unknown Error", response.statusCode);
      }

      return ApiResponse.fromJson<String>(response.data);
    } on DioException catch (e) {
      throw ServerException(
          e.message ?? "Unknown error", e.response?.statusCode);
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(e.toString(), null);
    }
  }
}
