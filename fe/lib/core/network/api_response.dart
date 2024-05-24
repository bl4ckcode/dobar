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

  static fromJson<T>(Map<dynamic, dynamic> json) {
    return ApiResponse<T>(
      statusCode: json['statusCode'],
      result: json['result'],
      error: json['error'],
    );
  }

  static fromJsonList<T>(Map<dynamic, dynamic> json, Function tFromJson) {
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
