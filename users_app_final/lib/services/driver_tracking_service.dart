import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:users_app/services/osrm_routing_service.dart';

/// Service de suivi en temps réel du chauffeur
class DriverTrackingService {
  static final _supabase = Supabase.instance.client;

  StreamSubscription? _locationSubscription;
  Timer? _etaUpdateTimer;

  final String driverId;
  final LatLng pickupLocation;
  final Function(LatLng position) onPositionUpdate;
  final Function(String eta, double distanceKm) onETAUpdate;
  final Function()? onDispose;

  LatLng? _lastPosition;
  bool _isActive = false;

  DriverTrackingService({
    required this.driverId,
    required this.pickupLocation,
    required this.onPositionUpdate,
    required this.onETAUpdate,
    this.onDispose,
  });

  /// Démarrer le suivi en temps réel
  void startTracking() {
    if (_isActive) return;
    _isActive = true;

    print('🔍 Démarrage tracking chauffeur: $driverId');

    _locationSubscription = _supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .listen((data) {
      if (data.isEmpty) return;

      final driver = data.first;
      final lat = (driver['current_latitude'] ?? driver['latitude']) as num?;
      final lng = (driver['current_longitude'] ?? driver['longitude']) as num?;

      if (lat != null && lng != null) {
        final newPosition = LatLng(lat.toDouble(), lng.toDouble());
        _lastPosition = newPosition;
        onPositionUpdate(newPosition);
      }
    });

    // Calculer l'ETA toutes les 15 secondes
    _etaUpdateTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _updateETA(),
    );

    // Premier calcul immédiat
    Future.delayed(const Duration(seconds: 2), _updateETA);
  }

  /// Calculer l'ETA du chauffeur vers le pickup
  Future<void> _updateETA() async {
    if (_lastPosition == null || !_isActive) return;

    try {
      final route = await OSRMRoutingService.getRoute(
        _lastPosition!,
        pickupLocation,
      );

      if (route != null) {
        final distanceKm = route.distanceInKm;
        final eta = route.trafficAdjustedDurationText;

        onETAUpdate(eta, distanceKm);
      }
    } catch (e) {
      print('⚠️ Erreur ETA chauffeur: $e');
    }
  }

  /// Obtenir la dernière position connue
  LatLng? get lastPosition => _lastPosition;
  bool get isActive => _isActive;

  /// Arrêter le suivi
  void stopTracking() {
    _isActive = false;
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _etaUpdateTimer?.cancel();
    _etaUpdateTimer = null;
    _lastPosition = null;
    onDispose?.call();

    print('🛑 Tracking chauffeur arrêté');
  }

  void dispose() {
    stopTracking();
  }
}
