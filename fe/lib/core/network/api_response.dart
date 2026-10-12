import 'package:flutter/foundation.dart';

class ApiResponse<T> {
  ApiResponse({
    required this.statusCode,
    required this.result,
    required this.error,
  });

  late final String? statusCode;
  late final T? result;
  late final T? error;

  // Factory method to create a success response
  factory ApiResponse.success(T result) {
    return ApiResponse<T>(
      statusCode: '200', // or any default success status code
      result: result,
      error: null,
    );
  }

  // Factory method to create an error response
  factory ApiResponse.error(String statusCode, T error) {
    return ApiResponse<T>(statusCode: statusCode, result: null, error: error);
  }

  static ApiResponse<T> fromJson<T>(Map<dynamic, dynamic> json) {
    return ApiResponse<T>(
      statusCode: json['statusCode'],
      result: json['result'],
      error: json['error'],
    );
  }

  static ApiResponse<T> fromJsonList<T>(
    Map<dynamic, dynamic> json,
    Function tFromJson,
  ) {
    return ApiResponse<T>(
      statusCode: json['statusCode'],
      result: tFromJson(json['result']),
      error: json['error'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    if (other is ApiResponse) {
      return other.result is List
          ? listEquals(other.result, result as List)
          : other.result == result;
    }

    return false;
  }

  @override
  int get hashCode => result.hashCode;
}
