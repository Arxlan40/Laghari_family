import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline }

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  final _controller = StreamController<NetworkStatus>.broadcast();

  NetworkStatus _currentStatus = NetworkStatus.online;
  NetworkStatus get currentStatus => _currentStatus;
  Stream<NetworkStatus> get onStatusChange => _controller.stream;

  NetworkService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateStatus(results);
    } catch (_) {
      _currentStatus = NetworkStatus.online;
      _controller.add(_currentStatus);
    }

    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final isOffline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);
    final newStatus = isOffline ? NetworkStatus.offline : NetworkStatus.online;

    if (newStatus != _currentStatus) {
      _currentStatus = newStatus;
      _controller.add(newStatus);
    }
  }

  void dispose() {
    _controller.close();
  }
}

final networkServiceProvider = Provider<NetworkService>((ref) {
  final service = NetworkService();
  ref.onDispose(() => service.dispose());
  return service;
});

final networkStatusStreamProvider = StreamProvider<NetworkStatus>((ref) {
  final service = ref.watch(networkServiceProvider);
  return service.onStatusChange;
});

final isOnlineProvider = Provider<bool>((ref) {
  final statusAsync = ref.watch(networkStatusStreamProvider);
  return statusAsync.valueOrNull != NetworkStatus.offline;
});
