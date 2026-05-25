import 'dart:async';
import 'package:users_app/services/trip_request_service.dart';
import 'package:users_app/services/supabase_service.dart';

class TripTimeoutService {
  static const int acceptanceTimeoutSeconds = 20; // 20 secondes
  static const int maxSearchAttempts = 3; // 5 tentatives max
  static const int radiusIncrement = 5000; // +5km par tentative

  Timer? _timeoutTimer;
  int _currentAttempt = 0;
  int _currentRadius = 5000;

  final String tripId;
  final String userId;
  final double pickupLat;
  final double pickupLng;
  final Function(int driversNotified) onDriversNotified;
  final Function(String message) onStatusUpdate;
  final Function() onNoDriversAvailable;
  final Function() onAccepted;

  TripTimeoutService({
    required this.tripId,
    required this.userId,
    required this.pickupLat,
    required this.pickupLng,
    required this.onDriversNotified,
    required this.onStatusUpdate,
    required this.onNoDriversAvailable,
    required this.onAccepted,
  });

  // ✅ Démarrer le système de timeout
  void start() {
    _currentAttempt = 1;
    _currentRadius = 5000;
    _startTimeoutTimer();
  }

  // ✅ Timer de 30 secondes
  void _startTimeoutTimer() {
    _timeoutTimer?.cancel();

    print("⏱️ Tentative $_currentAttempt/$maxSearchAttempts - Rayon ${_currentRadius}m - Timeout ${acceptanceTimeoutSeconds}s");

    onStatusUpdate(
        "Recherche de chauffeurs... (tentative $_currentAttempt/$maxSearchAttempts)"
    );

    _timeoutTimer = Timer(
      const Duration(seconds: acceptanceTimeoutSeconds),
      _onTimeout,
    );
  }

  // ✅ Appelé quand le timeout expire
  Future<void> _onTimeout() async {
    print("⏰ Timeout expiré pour tentative $_currentAttempt");

    // Vérifier si un chauffeur a accepté entre-temps
    final tripDetails = await TripRequestService.getTripDetails(tripId);

    if (tripDetails == null) {
      print("❌ Trip introuvable");
      onNoDriversAvailable();
      return;
    }

    final status = tripDetails['status'];

    // Si accepté, arrêter
    if (status == 'accepted') {
      print("✅ Chauffeur a accepté pendant le timeout");
      cancel();
      onAccepted();
      return;
    }

    // Si annulé, arrêter
    if (status == 'cancelled') {
      print("❌ Trip annulé");
      cancel();
      return;
    }

    // Si max tentatives atteint, annuler
    if (_currentAttempt >= maxSearchAttempts) {
      print("❌ Max tentatives atteint, annulation");
      await _cancelTripNoDrivers();
      return;
    }

    // Sinon, élargir la recherche
    await _expandSearch();
  }

  // ✅ Élargir le rayon de recherche
  Future<void> _expandSearch() async {
    _currentAttempt++;
    _currentRadius += radiusIncrement;

    print("📡 Élargissement rayon: ${_currentRadius}m (tentative $_currentAttempt)");

    onStatusUpdate(
        "Élargissement de la recherche... (rayon ${(_currentRadius / 1000).toStringAsFixed(1)} km)"
    );

    try {
      final result = await TripRequestService.expandSearchRadius(
        tripId: tripId,
        userId: userId,
        pickupLatitude: pickupLat,
        pickupLongitude: pickupLng,
        currentRadius: _currentRadius - radiusIncrement,
      );

      final driversNotified = result['driversNotified'] ?? 0;

      print("✅ $driversNotified nouveaux chauffeurs notifiés");

      onDriversNotified(driversNotified);

      if (driversNotified > 0) {
        // Redémarrer le timer
        _startTimeoutTimer();
      } else {
        // Aucun chauffeur trouvé, continuer quand même
        print("⚠️ Aucun nouveau chauffeur, nouvelle tentative dans ${acceptanceTimeoutSeconds}s");
        _startTimeoutTimer();
      }
    } catch (e) {
      print("❌ Erreur élargissement: $e");
      // Essayer quand même
      _startTimeoutTimer();
    }
  }

  // ✅ Annuler trip si aucun chauffeur
  Future<void> _cancelTripNoDrivers() async {
    try {
      await SupabaseService.supabase.rpc(
        'cancel_trip_no_drivers',
        params: {'p_trip_id': tripId},
      );

      print("❌ Trip annulé: aucun chauffeur disponible");
      onNoDriversAvailable();
    } catch (e) {
      print("❌ Erreur annulation: $e");
      onNoDriversAvailable();
    } finally {
      cancel();
    }
  }

  // ✅ Annuler le timer (si chauffeur accepte)
  void cancel() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    print("🛑 Timeout service arrêté");
  }

  // ✅ Obtenir le temps restant
  int get currentAttempt => _currentAttempt;
  int get currentRadius => _currentRadius;
  bool get isActive => _timeoutTimer != null && _timeoutTimer!.isActive;

  /// Forcer l'élargissement manuel (sans attendre le timeout)
  Future<void> expandSearchManually() async {
    if (_timeoutTimer != null && _timeoutTimer!.isActive) {
      _timeoutTimer?.cancel();
    }
    await _expandSearch();
  }
}

