class ServerException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic> details;

  ServerException(this.message, this.statusCode, {this.details = const {}});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    if (other is ServerException) {
      return other.message == message &&
          other.statusCode == statusCode &&
          other.details.toString() == details.toString();
    }

    return false;
  }

  @override
  int get hashCode => Object.hash(message, statusCode, details.toString());
}
