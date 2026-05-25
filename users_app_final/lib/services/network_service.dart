import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Service centralisé de gestion réseau
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkStatus> _statusController =
      StreamController<NetworkStatus>.broadcast();

  NetworkStatus _currentStatus = NetworkStatus.online;
  StreamSubscription? _connectivitySubscription;

  /// Status actuel
  NetworkStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus == NetworkStatus.online;
  bool get isOffline => _currentStatus != NetworkStatus.online;

  /// Stream du status réseau
  Stream<NetworkStatus> get statusStream => _statusController.stream;

  /// Initialiser la surveillance réseau
  Future<void> initialize() async {
    await _checkConnectivity();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) async {
        await _checkConnectivity();
      },
    );
  }

  /// Vérifier la connectivité
  Future<NetworkStatus> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();

      bool hasConnection;
      if (connectivityResult is List) {
        hasConnection = (connectivityResult as List).any(
          (r) =>
              r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
        );
      } else {
        hasConnection = connectivityResult == ConnectivityResult.mobile ||
            connectivityResult == ConnectivityResult.wifi;
      }

      if (!hasConnection) {
        _updateStatus(NetworkStatus.offline);
        return _currentStatus;
      }

      // Vérifier la connectivité réelle avec un ping
      try {
        final response = await http
            .get(Uri.parse('https://nominatim.openstreetmap.org/status'))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          _updateStatus(NetworkStatus.online);
        } else {
          _updateStatus(NetworkStatus.slow);
        }
      } catch (_) {
        _updateStatus(NetworkStatus.slow);
      }
    } catch (_) {
      _updateStatus(NetworkStatus.offline);
    }

    return _currentStatus;
  }

  void _updateStatus(NetworkStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
      print('🌐 Réseau: ${status.label}');
    }
  }

  /// Exécuter une requête avec retry
  static Future<T?> withRetry<T>({
    required Future<T> Function() action,
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        if (attempt == maxRetries) {
          print('❌ Échec après $maxRetries tentatives: $e');
          rethrow;
        }
        final delay = initialDelay * attempt;
        print('⚠️ Tentative $attempt échouée, retry dans ${delay.inMilliseconds}ms');
        await Future.delayed(delay);
      }
    }
    return null;
  }

  /// Disposer les ressources
  void dispose() {
    _connectivitySubscription?.cancel();
    _statusController.close();
  }
}

/// Status du réseau
enum NetworkStatus { online, slow, offline }

extension NetworkStatusExt on NetworkStatus {
  String get label {
    switch (this) {
      case NetworkStatus.online:
        return 'En ligne';
      case NetworkStatus.slow:
        return 'Connexion lente';
      case NetworkStatus.offline:
        return 'Hors ligne';
    }
  }

  bool get isConnected => this != NetworkStatus.offline;
}
