import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum NetworkStatus { online, offline }

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final _statusController = StreamController<NetworkStatus>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  NetworkStatus _currentStatus = NetworkStatus.online;
  bool _isInitialized = false;

  final List<VoidCallback> _onReconnectCallbacks = [];

  NetworkStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus == NetworkStatus.online;
  bool get isOffline => _currentStatus == NetworkStatus.offline;
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    final results = await _connectivity.checkConnectivity();
    _updateStatus(_mapResults(results));

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final newStatus = _mapResults(results);
      final wasOffline = _currentStatus == NetworkStatus.offline;
      _updateStatus(newStatus);

      if (wasOffline && newStatus == NetworkStatus.online) {
        debugPrint('[Connectivity] Back online - triggering sync callbacks');
        _triggerReconnectCallbacks();
      }
    });
  }

  NetworkStatus _mapResults(List<ConnectivityResult> results) {
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.online;
  }

  void _updateStatus(NetworkStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
      debugPrint('[Connectivity] Status: ${status.name}');
    }
  }

  void registerOnReconnect(VoidCallback callback) {
    _onReconnectCallbacks.add(callback);
  }

  void unregisterOnReconnect(VoidCallback callback) {
    _onReconnectCallbacks.remove(callback);
  }

  void _triggerReconnectCallbacks() {
    for (final callback in _onReconnectCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('[Connectivity] Callback error: $e');
      }
    }
  }

  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(_mapResults(results));
    return isOnline;
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}
