import 'package:barz/core/api/api_endpoints.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class BaseSocketService {
  /// The base URL for the WebSocket connection.
  final String socketBaseUrl = "/ws";
  late final WebSocketChannel _channel;

  /// Creates a socket connection by appending [endpoint] to the base URL.
  ///
  /// For example, if your server is hosted at "ws://example.com", then for a menus socket
  /// the full URL would be "ws://example.com/ws/menus".
  BaseSocketService(String endpoint) {
    // Convert https to wss for WebSocket
    final wsBaseUrl = ApiEndpoints.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');

    final String fullUrl = "$wsBaseUrl$socketBaseUrl/$endpoint";
    _channel = WebSocketChannel.connect(Uri.parse(fullUrl));
  }

  /// Exposes the stream of incoming messages.
  Stream get messages => _channel.stream;

  /// Sends a [message] to the socket.
  void send(dynamic message) {
    _channel.sink.add(message);
  }

  /// Closes the socket connection.
  void close() {
    _channel.sink.close();
  }
}
