import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_exceptions.dart';

class ApiClient {
  final String baseUrl;
  String? _authToken;

  ApiClient({required this.baseUrl});

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final url = Uri.parse('$baseUrl$path');
    final requestHeaders = <String, String>{
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      ...?headers,
    };
    http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: requestHeaders);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            url,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: requestHeaders);
          break;
        default:
          throw Exception('Unsupported HTTP method');
      }
    } catch (_) {
      throw NetworkException();
    }
    switch (response.statusCode) {
      case 200:
      case 201:
        return jsonDecode(response.body);
      case 204:
        return null;
      case 400:
        throw ValidationException();
      case 401:
        throw AuthException();
      case 403:
        throw PermissionException();
      case 404:
        throw NotFoundException();
      case 500:
      default:
        throw ServerException();
    }
  }
}
