import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Represents a WebSocket message from the server
class WebSocketMessage {
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  WebSocketMessage({
    required this.type,
    required this.data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] ?? 'unknown',
      data: json,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Connection state for the WebSocket
enum WebSocketState { disconnected, connecting, connected, reconnecting, error }

/// Generic WebSocket service with automatic reconnection
///
/// Usage:
/// ```dart
/// final ws = WebSocketService(
///   baseUrl: 'wss://barz-backend.fly.dev',
///   path: '/ws/orders/123/status',
///   token: userToken,
/// );
///
/// ws.messages.listen((message) {
///   print('Received: ${message.type}');
/// });
///
/// await ws.connect();
/// ws.send({'action': 'ping'});
/// ```
class WebSocketService {
  final String baseUrl;
  final String path;
  final String? token;
  final Duration reconnectDelay;
  final Duration heartbeatInterval;
  final int maxReconnectAttempts;

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;

  final _stateController = StreamController<WebSocketState>.broadcast();
  final _messageController = StreamController<WebSocketMessage>.broadcast();

  WebSocketState _currentState = WebSocketState.disconnected;

  WebSocketService({
    required this.baseUrl,
    required this.path,
    this.token,
    this.reconnectDelay = const Duration(seconds: 3),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.maxReconnectAttempts = 10,
  });

  /// Stream of connection state changes
  Stream<WebSocketState> get stateStream => _stateController.stream;

  /// Current connection state
  WebSocketState get state => _currentState;

  /// Stream of incoming messages
  Stream<WebSocketMessage> get messages => _messageController.stream;

  /// Whether the WebSocket is currently connected
  bool get isConnected => _currentState == WebSocketState.connected;

  /// Build the full WebSocket URL with token
  Uri get _wsUri {
    final uri = Uri.parse('$baseUrl$path');
    if (token != null) {
      return uri.replace(
        queryParameters: {...uri.queryParameters, 'token': token},
      );
    }
    return uri;
  }

  /// Connect to the WebSocket server
  Future<void> connect() async {
    if (_isDisposed) return;
    if (_currentState == WebSocketState.connected ||
        _currentState == WebSocketState.connecting) {
      return;
    }

    _updateState(WebSocketState.connecting);

    try {
      _channel = WebSocketChannel.connect(_wsUri);

      // Wait for the connection to be ready
      await _channel!.ready;

      _reconnectAttempts = 0;
      _updateState(WebSocketState.connected);
      _startHeartbeat();

      // Listen for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
        cancelOnError: false,
      );

      debugPrint('[WebSocket] Connected to $_wsUri');
    } catch (e) {
      debugPrint('[WebSocket] Connection error: $e');
      _updateState(WebSocketState.error);
      _scheduleReconnect();
    }
  }

  /// Send a message to the server
  void send(Map<String, dynamic> message) {
    if (_channel != null && isConnected) {
      final jsonMessage = jsonEncode(message);
      _channel!.sink.add(jsonMessage);
      debugPrint('[WebSocket] Sent: $jsonMessage');
    } else {
      debugPrint('[WebSocket] Cannot send - not connected');
    }
  }

  /// Send a typed action (convenience method)
  void sendAction(String action, {Map<String, dynamic>? payload}) {
    final message = {'action': action, if (payload != null) ...payload};
    send(message);
  }

  /// Disconnect and clean up
  Future<void> disconnect() async {
    _isDisposed = true;
    _stopHeartbeat();
    _reconnectTimer?.cancel();

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        debugPrint('[WebSocket] Error closing sink: $e');
      }
      _channel = null;
    }

    _updateState(WebSocketState.disconnected);
    debugPrint('[WebSocket] Disconnected');
  }

  /// Dispose of the service (call when no longer needed)
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _messageController.close();
  }

  void _handleMessage(dynamic data) {
    final raw = data.toString();

    // Handle plain-text server control frames (e.g. 'connected', 'error')
    if (raw == 'connected') {
      debugPrint('[WebSocket] Received: connected');
      return;
    }
    if (raw == 'error') {
      debugPrint('[WebSocket] Received: error');
      return;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final message = WebSocketMessage.fromJson(json);

      if (message.type == 'pong') return;

      _messageController.add(message);
      debugPrint('[WebSocket] Received: ${message.type}');
    } catch (e) {
      debugPrint('[WebSocket] Error parsing message: $e | raw: $raw');
    }
  }

  void _handleError(dynamic error) {
    debugPrint('[WebSocket] Error: $error');
    _updateState(WebSocketState.error);
    _scheduleReconnect();
  }

  void _handleDone() {
    debugPrint('[WebSocket] Connection closed');
    _stopHeartbeat();

    if (!_isDisposed) {
      _updateState(WebSocketState.disconnected);
      _scheduleReconnect();
    }
  }

  void _updateState(WebSocketState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    // Heartbeat is handled via native WebSocket ping frames by the browser.
    // We only set up a timer to detect stale connections if needed.
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_reconnectAttempts >= maxReconnectAttempts) {
      debugPrint('[WebSocket] Max reconnect attempts reached');
      _updateState(WebSocketState.error);
      return;
    }

    _reconnectTimer?.cancel();
    _updateState(WebSocketState.reconnecting);

    final delay = reconnectDelay * (_reconnectAttempts + 1);
    debugPrint(
      '[WebSocket] Reconnecting in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1}/$maxReconnectAttempts)',
    );

    _reconnectTimer = Timer(delay, () {
      _reconnectAttempts++;
      connect();
    });
  }
}
