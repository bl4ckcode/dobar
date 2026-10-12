import 'package:barz/core/api/api_endpoints.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BaseRepository {
  final String baseUrl = ApiEndpoints.baseUrl;

  Future<Map<String, dynamic>> login(
    String phoneNumber,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: jsonEncode(<String, String>{
        'phone_number': phoneNumber,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to log in');
    }
  }
}
