import 'package:dio/dio.dart';

class DioNetwork {
  static late Dio appAPI;
  static late Dio retryAPI;

  static void initDio() {
    appAPI = Dio();
  }

  static BaseOptions baseOptions(String url) {
    Map<String, dynamic> headers = {};

    return BaseOptions(
        baseUrl: url,
        validateStatus: (s) {
          return s! < 300;
        },
        headers: headers..removeWhere((key, value) => true),
        responseType: ResponseType.json);
  }
}
