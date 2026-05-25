import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// App imports
import 'package:users_app/authentication/login_screen_supabase.dart';
import 'package:users_app/pages/recent_locations_page_supabase.dart';
import 'package:users_app/pages/work_location_page_supabase.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/methods/common_methods.dart';
import 'package:users_app/models/address_model.dart';
import 'package:users_app/pages/search_destination_page.dart';
import 'package:users_app/pages/favorite_locations_page.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:users_app/services/osm_map_service.dart';
import 'package:users_app/services/osrm_routing_service.dart';
import 'package:users_app/widgets/modern_drawer_supabase.dart';
import 'package:users_app/widgets/payment_dialog_supabase.dart';
import 'package:users_app/widgets/rating_dialog_supabase.dart';
import 'package:users_app/pages/emergency_page.dart';
import 'package:users_app/pages/trip_chat_page.dart';
import 'package:users_app/services/trip_request_service.dart';

import '../global/global_var_supabase.dart';
import '../services/trip_timeout_service.dart';
import 'package:users_app/services/driver_tracking_service.dart';
import 'package:users_app/services/notification_service.dart';
import 'package:users_app/services/network_service.dart';
import 'package:users_app/widgets/offline_banner.dart';
import 'package:users_app/widgets/status_timeline.dart';
import 'package:users_app/widgets/fare_breakdown.dart';
import 'package:users_app/widgets/trip_share_sheet.dart';
import 'package:users_app/methods/fare_calculator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final CommonMethods _cMethods = CommonMethods();

  // États de l'interface
  double _searchContainerHeight = 276;
  double _rideDetailsHeight = 0;
  double _driverDetailsHeight = 0;

  // Route et infos
  String _distance = "";
  String _duration = "";
  String _fareAmount = "";
  LatLng? _pickupLatLng;
  LatLng? _destinationLatLng;
  String _pickupAddress = "";
  String _destinationAddress = "";

  // Infos du chauffeur
  String _driverName = "";
  String _driverPhone = "";
  String _driverPhoto = "";
  String _carDetails = "";
  String _carNumber = "";
  String _tripStatus = "";
  String? _currentTripID;
  String? _driverID;
  String _driverRatings = "5.0";
  String _carPhoto = ""; // ✅ AJOUTER

  List<Polyline> _polylines = [];
  final List<Marker> _markers = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Gestion des chauffeurs (Supabase)
  StreamSubscription? _driversSubscription;
  StreamSubscription? _tripSubscription;
  bool _isSearchingDriver = false;
  List<Marker> _driverMarkers = [];

  // AJOUTER CES 4 NOUVELLES VARIABLES ICI
  int _driversNotified = 0;
  int _currentSearchRadius = 5000;
  Timer? _searchTimer;
  bool _isExpandingSearch = false;

  TripTimeoutService? _timeoutService;
  int _searchAttempt = 0;
  int _totalDriversNotified = 0;
  String _searchStatus = "";

  StreamSubscription<Map<String, dynamic>>? _tripStatusSubscription;
  Timer? _tripStatusPollingTimer; // ✅ Ajout du timer de polling de secours

  // ✅ NOUVEAUX: Tracking, réseau, ETA
  DriverTrackingService? _driverTrackingService;
  NetworkStatus _networkStatus = NetworkStatus.online;
  StreamSubscription? _networkSubscription;
  String? _driverETA;
  double? _driverDistanceKm;
  String _carColor = "";

  // ✅ Polling fallback chauffeurs + optimisation re-renders
  Timer? _driversPollingTimer;
  Map<String, LatLng> _previousDriverPositions = {};

  // ✅ Guard anti-doublon pour acceptation trip
  bool _tripAcceptedHandled = false;

  // ✅ WebSocket channels pour messages admin et tarification
  RealtimeChannel? _adminMessageChannel;
  RealtimeChannel? _appSettingsChannel;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _initData();
    _listenToOnlineDrivers();
    _initNetworkMonitoring();
    _subscribeToAdminMessages();
    _subscribeToAppSettings();
  }

  // ✅ WebSocket: Écouter les messages admin en temps réel
  void _subscribeToAdminMessages() {
    _adminMessageChannel?.unsubscribe();
    _adminMessageChannel = SupabaseService.subscribeToAdminMessages(
      onNewMessage: (msgData) async {
        if (!mounted) return;
        final title = msgData['title']?.toString() ?? 'Le Bon Taxi';
        final message = msgData['message']?.toString() ?? '';
        // Notification système
        await NotificationService.showLocalNotification(
          title: '📢 $title',
          body: message,
        );
        // Dialog dans l'app
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                const Icon(Icons.campaign, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ]),
              content: Text(message),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
            ),
          );
        }
      },
    );
  }

  // ✅ WebSocket: Écouter les changements de tarification
  void _subscribeToAppSettings() {
    _appSettingsChannel?.unsubscribe();
    _appSettingsChannel = SupabaseService.subscribeToAppSettings(
      onSettingsChanged: (settings) {
        if (!mounted) return;
        print('💰 Tarification mise à jour via WebSocket dans l\'app client');
      },
    );
  }

  Future<void> _showCancelConfirmation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.warning, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Annuler la recherche ?",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Voulez-vous vraiment annuler cette demande de course ?",
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$_totalDriversNotified chauffeur${_totalDriversNotified > 1 ? 's' : ''} ${_totalDriversNotified > 1 ? 'ont' : 'a'} été notifié${_totalDriversNotified > 1 ? 's' : ''}",
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Continuer la recherche"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("Oui, annuler"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cancelTrip();
    }
  }

  Future<void> _initData() async {
    await SupabaseService.fetchPricingConfig();
    await _loadUserInfo();
    await _checkLocationPermission();
  }

  // ✅ CHARGER INFO UTILISATEUR (Supabase)
  Future<void> _loadUserInfo() async {
    try {
      if (!SupabaseService.isAuthenticated) return;

      final profile = await SupabaseService.getUserProfile();

      if (profile != null) {
        if (profile['block_status'] == 'no') {
          setState(() {
            userName = profile['name'] ?? '';
            userPhone = profile['phone'] ?? '';
            userEmail = profile['email'] ?? '';
          });
          
          // ✅ Charger le statut d'abonnement via la méthode centralisée
          await SupabaseService.loadUserSubscriptionStatus();
          if (mounted) setState(() {});

        } else {
          _logout();
        }
      }
    } catch (e) {
      print("❌ Erreur chargement user: $e");
    }
  }

  void _logout() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreenSupabase()),
      );
    }
  }

  Future<void> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      await _getCurrentLocation();
    }
  }

  // ✅ Appelé quand la carte FlutterMap est prête
  void _onMapReady() {
    // Si on a déjà la position, centrer la carte dessus
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0,
      );
      _addUserMarker();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      setState(() => _currentPosition = position);

      // ✅ Ajouter le marker IMMÉDIATEMENT après avoir la position
      _addUserMarker();

      // ✅ Attendre que le map controller soit prêt avant de bouger la caméra
      try {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          16.0,
        );
      } catch (e) {
        // Le controller n'est pas encore attaché, on réessaie après le prochain frame
        print("⚠️ MapController pas prêt, retry après frame...");
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentPosition != null) {
            try {
              _mapController.move(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                16.0,
              );
            } catch (e2) {
              print("⚠️ MapController toujours pas prêt: $e2");
            }
          }
        });
      }

      // Reverse geocoding en arrière-plan (ne bloque pas l'affichage du marker)
      try {
        await CommonMethods.convertToAddress(position, context);
      } catch (e) {
        print("⚠️ Erreur reverse geocoding: $e");
      }
    } catch (e) {
      print("❌ Erreur position: $e");
    }
  }

  void _addUserMarker() {
    if (_currentPosition == null) return;

    setState(() {
      _markers.removeWhere((m) => m.key == const Key("user_position"));
      _markers.add(
        Marker(
          key: const Key("user_position"),
          point:
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 60,
          height: 60,
          child: ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.circle,
                color: Colors.blue,
                size: 20,
              ),
            ),
          ),
        ),
      );
    });
  }

  // ✅ ÉCOUTER CHAUFFEURS EN LIGNE (Stream Supabase + Polling fallback)
  void _listenToOnlineDrivers() async {
    // Attendre que la position soit disponible
    int attempts = 0;
    while (_currentPosition == null && attempts < 15) {
      await Future.delayed(const Duration(seconds: 1));
      attempts++;
    }

    if (_currentPosition == null) {
      print("❌ Position non disponible pour chauffeurs");
      return;
    }

    // 1. Stream Supabase (temps réel si Realtime est activé)
    try {
      _driversSubscription = SupabaseService.supabase
          .from('drivers')
          .stream(primaryKey: ['id'])
          .eq('is_online', true)
          .listen(
            (drivers) {
              print("📡 Stream chauffeurs: ${drivers.length} en ligne");
              _updateDriverMarkers(drivers);
            },
            onError: (e) {
              print("⚠️ Stream chauffeurs erreur: $e — fallback polling actif");
            },
          );
    } catch (e) {
      print("❌ Erreur stream chauffeurs: $e");
    }

    // 2. Polling fallback (toutes les 10s) — garantit la mise à jour
    _startDriversPolling();
  }

  /// Démarrer le polling de secours pour les chauffeurs en ligne
  void _startDriversPolling() {
    _driversPollingTimer?.cancel();
    // Premier poll immédiat
    _pollOnlineDrivers();
    // Puis toutes les 10 secondes
    _driversPollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _pollOnlineDrivers(),
    );
  }

  /// Polling direct sur la table drivers
  Future<void> _pollOnlineDrivers() async {
    if (_currentPosition == null || !mounted) return;
    try {
      final drivers = await SupabaseService.supabase
          .from('drivers')
          .select()
          .eq('is_online', true);
      // ✅ TOUJOURS mettre à jour, même si liste vide (nettoyer anciens marqueurs)
      _updateDriverMarkers(List<Map<String, dynamic>>.from(drivers));
    } catch (e) {
      print("⚠️ Polling chauffeurs échoué: $e");
    }
  }

  /// Construire le widget marqueur chauffeur (réutilisable)
  Widget _buildDriverMarkerWidget() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: AppColors.primary, width: 2.5),
          ),
        ),
        const Icon(
          Icons.directions_car,
          color: AppColors.primary,
          size: 26,
        ),
      ],
    );
  }

  void _updateDriverMarkers(List<Map<String, dynamic>> drivers) {
    if (_currentPosition == null) return;

    Map<String, LatLng> newPositions = {};
    List<Marker> newMarkers = [];

    for (var driver in drivers) {
      final driverId = driver['id']?.toString() ?? '';
      // ✅ Gérer latitude ou current_latitude pour le temps réel
      var rawLat = driver['current_latitude'] ?? driver['latitude'];
      var rawLng = driver['current_longitude'] ?? driver['longitude'];

      final lat = rawLat is int ? rawLat.toDouble() : rawLat as double?;
      final lng = rawLng is int ? rawLng.toDouble() : rawLng as double?;

      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        // Calculer distance avec Geolocator
        final distance = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        );

        // ✅ Afficher chauffeurs dans rayon 10km (augmenté de 5km)
        if (distance <= 10000) {
          final pos = LatLng(lat, lng);
          newPositions[driverId] = pos;
          newMarkers.add(
            Marker(
              key: Key("driver_$driverId"), // ✅ Key unique par chauffeur
              point: pos,
              width: 50,
              height: 50,
              child: _buildDriverMarkerWidget(),
            ),
          );
        }
      }
    }

    // ✅ Toujours mettre à jour si c'est le premier rendu ou si les positions ont changé
    if (_previousDriverPositions.isEmpty || _hasDriverPositionsChanged(newPositions)) {
      _previousDriverPositions = newPositions;
      if (mounted) {
        setState(() {
          _driverMarkers = newMarkers;
        });
        if (newMarkers.isNotEmpty) {
          print("🚕 ${newMarkers.length} chauffeur(s) affiché(s) sur la carte");
        }
      }
    }
  }

  /// Vérifier si les positions des chauffeurs ont changé (seuil de 10m)
  bool _hasDriverPositionsChanged(Map<String, LatLng> newPositions) {
    if (newPositions.length != _previousDriverPositions.length) return true;
    for (var entry in newPositions.entries) {
      final prev = _previousDriverPositions[entry.key];
      if (prev == null) return true;
      // Seuil de 10m pour éviter les re-renders sur micro-mouvements
      final dist = Geolocator.distanceBetween(
        prev.latitude, prev.longitude,
        entry.value.latitude, entry.value.longitude,
      );
      if (dist > 10) return true;
    }
    return false;
  }

  void _showNoDriversFoundDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Aucun chauffeur disponible",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Nous avons cherché dans un rayon de 25 km mais aucun chauffeur n'est disponible pour le moment.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Chauffeurs contactés :"),
                      Text(
                        "$_totalDriversNotified",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Tentatives :"),
                      Text(
                        "$_searchAttempt/3",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resetApp();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "Réessayer plus tard",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // DEMANDER UNE COURSE (Supabase avec notifications)
  Future<void> _requestRide() async {
    if (!SupabaseService.isAuthenticated) {
      _cMethods.displaySnackBar("Vous devez être connecté", context);
      return;
    }

    // ✅ FERMER le container de détails
    setState(() {
      _rideDetailsHeight = 0;
      _searchContainerHeight = 0;
    });

    // ✅ AFFICHER l'UI de recherche IMMÉDIATEMENT
    setState(() {
      _isSearchingDriver = true;
      _searchAttempt = 0;
      _totalDriversNotified = 0;
      _searchStatus = "Initialisation...";
    });

    final tripId = DateTime.now().millisecondsSinceEpoch.toString();

    try {
      // Créer le trip
      final result = await TripRequestService.createTripRequest(
        tripId: tripId,
        userId: SupabaseService.userId!,
        userName: userName,
        userPhone: userPhone,
        pickupAddress: _pickupAddress,
        dropoffAddress: _destinationAddress,
        pickupLatitude: _pickupLatLng!.latitude,
        pickupLongitude: _pickupLatLng!.longitude,
        dropoffLatitude: _destinationLatLng!.latitude,
        dropoffLongitude: _destinationLatLng!.longitude,
        distance: _distance,
        duration: _duration,
        fareAmount: _fareAmount.replaceAll(' HTG', ''),
        searchRadius: 5000,
      );

      if (!result['success']) throw Exception(result['error']);

      _currentTripID = tripId;
      final initialDrivers = result['driversNotified'] ?? 0;

      setState(() {
        _totalDriversNotified = initialDrivers;
        _searchAttempt = 1;
        _searchStatus = initialDrivers > 0
            ? "En attente de réponse..."
            : "Aucun chauffeur proche, élargissement...";
      });

      // Démarrer le timeout service
      _timeoutService = TripTimeoutService(
        tripId: tripId,
        userId: SupabaseService.userId!,
        pickupLat: _pickupLatLng!.latitude,
        pickupLng: _pickupLatLng!.longitude,
        onDriversNotified: (count) {
          if (!mounted) return;
          setState(() {
            _totalDriversNotified += count;
            _searchAttempt = _timeoutService?.currentAttempt ?? 1;
            _searchStatus = count > 0
                ? "En attente de réponse..."
                : "Élargissement en cours...";
          });
        },
        onStatusUpdate: (message) {
          if (!mounted) return;
          setState(() {
            _searchStatus = message;
          });
        },
        onNoDriversAvailable: () {
          if (!mounted) return;
          setState(() {
            _isSearchingDriver = false;
            _searchStatus = "";
          });
          _showNoDriversFoundDialog();
        },
        onAccepted: () async {
          if (!mounted) return;
          
          // ✅ Déléguer à _handleTripData (qui a le guard anti-doublon)
          final tripData = await TripRequestService.pollTripStatus(tripId);
          if (tripData != null && mounted) {
            _handleTripData(tripData);
          }
        },
      );

      _timeoutService!.start();
      _listenToTripStatus(tripId);
      
      // ✅ POLLING DE SECOURS (toutes les 3 secondes)
      _tripStatusPollingTimer?.cancel();
      _tripStatusPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final tripData = await TripRequestService.pollTripStatus(tripId);
        if (tripData != null) {
          _handleTripData(tripData);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearchingDriver = false;
        _searchStatus = "";
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Erreur"),
          content: Text("Impossible de créer la demande:\n${e.toString()}"),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    }
  }

// DÉMARRER TIMER POUR EXTENSION AUTOMATIQUE
  void _startSearchTimer() {
    // Si pas de réponse après 30 secondes, étendre le rayon
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(seconds: 30), () {
      if (_isSearchingDriver && _tripStatus == '') {
        _expandSearchRadius();
      }
    });
  }

// ÉTENDRE RAYON DE RECHERCHE
  Future<void> _expandSearchRadius() async {
    if (_isExpandingSearch || _currentTripID == null) return;

    setState(() => _isExpandingSearch = true);

    print("📡 Extension rayon de recherche...");

    try {
      final result = await TripRequestService.expandSearchRadius(
        tripId: _currentTripID!,
        userId: SupabaseService.userId!,
        pickupLatitude: _pickupLatLng!.latitude,
        pickupLongitude: _pickupLatLng!.longitude,
        currentRadius: _currentSearchRadius,
      );

      if (result['success']) {
        // ✅ CORRECTION ICI
        final newRadius =
            (result['newRadius'] as num?)?.toInt() ?? _currentSearchRadius;
        final newDrivers = (result['driversNotified'] as num?)?.toInt() ?? 0;

        setState(() {
          _currentSearchRadius = newRadius;
          _driversNotified += newDrivers;
        });

        if (newDrivers > 0) {
          _cMethods.displaySnackBar(
            "Recherche étendue: $newDrivers nouveau${newDrivers > 1 ? 'x' : ''} chauffeur${newDrivers > 1 ? 's' : ''} notifié${newDrivers > 1 ? 's' : ''}",
            context,
          );

          _startSearchTimer();
        } else {
          _showNoDriversDialog();
        }
      }
    } catch (e) {
      print("❌ Erreur extension rayon: $e");
    } finally {
      setState(() => _isExpandingSearch = false);
    }
  }

// ✅ DIALOG AUCUN CHAUFFEUR DISPONIBLE
  void _showNoDriversDialog() {
    _searchTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.warning, size: 28),
            SizedBox(width: 12),
            Text("Aucun chauffeur"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Aucun chauffeur disponible dans votre zone pour le moment.",
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),
            Text(
              "Rayon de recherche actuel : ${(_currentSearchRadius / 1000).toStringAsFixed(1)} km",
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelTrip();
            },
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _expandSearchRadius();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text("Élargir recherche"),
          ),
        ],
      ),
    );
  }

  // ✅ ÉCOUTER STATUT TRIP (Supabase Realtime)
  void _listenToTripStatus(String tripId) {
    _tripStatusSubscription?.cancel();

    _tripStatusSubscription =
        TripRequestService.listenToTripStatus(tripId).listen((tripData) {
      _handleTripData(tripData);
    });
  }

  // ✅ TRAITER LES DONNÉES DU TRIP (Appelé par Realtime OU Polling)
  Future<void> _handleTripData(Map<String, dynamic> tripData) async {
    if (!mounted) return;

    final status = tripData['status'] as String?;
    if (status == null || status == 'new') return; // Ignore 'new' as it's the initial state

    // Si on détecte un changement significatif, c'est l'un de ces statuts
    if (status == 'accepted') {
      // ✅ Guard anti-doublon : polling + stream + timeout peuvent tous déclencher
      if (_tripAcceptedHandled) return;
      _tripAcceptedHandled = true;

      // ✅ Arrêter TOUT immédiatement
      _timeoutService?.cancel();
      _tripStatusPollingTimer?.cancel();
      _tripStatusSubscription?.cancel();

      // Phase 1 : "Chauffeur trouvé ✓" — affichage intermédiaire (1.5s)
      setState(() {
        _searchStatus = "Chauffeur trouvé ✓";
        _tripStatus = 'found'; // Status intermédiaire pour l'animation verte
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // Phase 2 : Transition vers les détails du chauffeur
      setState(() {
        _tripStatus = status;
        _driverID = tripData['driver_id'];
        _isSearchingDriver = false;
        _rideDetailsHeight = 0;
        _searchStatus = "";
        _driverName = tripData['driver_name']?.toString() ?? 'Chauffeur';
        _driverPhone = tripData['driver_phone']?.toString() ?? '';
        _driverRatings = (tripData['driver_rating'] ?? 5.0).toString();
        _driverPhoto = tripData['driver_photo']?.toString() ?? '';
        // ✅ FIX: Le driver envoie 'car_model', supporter les deux noms de colonnes
        _carDetails = (tripData['car_details'] ?? tripData['car_model'])?.toString() ?? 'Véhicule';
        _carNumber = tripData['car_number']?.toString() ?? '';
        _carPhoto = tripData['car_photo']?.toString() ?? '';
        _carColor = tripData['car_color']?.toString() ?? '';
        _driverDetailsHeight = 340;
      });

      // Charger info chauffeur complète si driver_id disponible
      if (tripData['driver_id'] != null) {
        _loadDriverInfo(tripData['driver_id'].toString());
      }

      // ✅ Réécouter le statut du trip pour les états suivants (arrived, ontrip, completed)
      if (_currentTripID != null) {
        _listenToTripStatus(_currentTripID!);
        _tripStatusPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
          if (!mounted) { timer.cancel(); return; }
          final data = await TripRequestService.pollTripStatus(_currentTripID!);
          if (data != null) _handleTripData(data);
        });
      }

      _cMethods.displaySnackBar("✅ $_driverName a accepté votre demande !", context);
    } else if (_tripStatus != status) {
      // Pour les autres statuts (arrived, ontrip, completed, ended, cancelled)
      setState(() {
        _tripStatus = status;
        _driverID = tripData['driver_id'];
      });

      switch (status) {
        case 'arrived':
          // ✅ FIX #2: Notification riche + push locale au lieu d'un simple SnackBar
          _showDriverArrivedAlert();
          break;

        case 'ontrip':
          _cMethods.displaySnackBar("🚀 Course en cours", context);
          break;

        // ✅ FIX #3: Le driver envoie 'completed', pas 'ended'
        case 'completed':
        case 'ended':
          _tripStatusSubscription?.cancel();
          _tripStatusPollingTimer?.cancel();
          // ✅ Relire les données du trip pour avoir le montant final
          await _handleTripCompleted();
          break;

        case 'cancelled':
          _timeoutService?.cancel();
          _tripStatusSubscription?.cancel();
          _tripStatusPollingTimer?.cancel();
          _resetApp();
          _cMethods.displaySnackBar("Course annulée", context);
          break;
      }
    }
  }

  Future<void> _loadDriverInfo(String driverID) async {
    try {
      final driver = await SupabaseService.supabase
          .from('drivers')
          .select()
          .eq('id', driverID)
          .single();

      if (mounted) {
        setState(() {
          // ✅ FIX: Utiliser .toString() pour éviter les erreurs de type Map/int → String
          _driverName = driver['name']?.toString() ?? 'Chauffeur';
          _driverPhone = driver['phone']?.toString() ?? '';
          _driverPhoto = driver['photo']?.toString() ?? '';
          // ✅ FIX: Supporter car_model (driver app) et car_details (user app)
          _carDetails = (driver['car_details'] ?? driver['car_model'])?.toString() ?? '';
          _carNumber = driver['car_number']?.toString() ?? '';
          _carPhoto = driver['car_photo']?.toString() ?? '';
          _carColor = driver['car_color']?.toString() ?? '';
          _driverRatings = (driver['average_rating'] ?? driver['rating'] ?? 5.0).toString();
        });
      }

      // ✅ Démarrer le tracking du chauffeur
      if (_pickupLatLng != null) {
        _startDriverTracking(driverID);
      }
    } catch (e) {
      print("❌ Erreur chargement chauffeur: $e");
    }
  }

  // ✅ FIX #2: Alerte riche "Chauffeur arrivé" avec notification push
  void _showDriverArrivedAlert() {
    // 1. Notification push locale (même en arrière-plan)
    NotificationService.showDriverArrivedNotification(
      driverName: _driverName,
      carDetails: _carDetails,
    );

    // 2. Dialog riche in-app
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône animée
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Votre chauffeur est arrivé !",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Photo + nom du chauffeur
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: _driverPhoto.isNotEmpty
                      ? NetworkImage(_driverPhoto)
                      : null,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: _driverPhoto.isEmpty
                      ? const Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _driverName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$_carDetails • $_carNumber",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Rendez-vous au point de départ pour commencer votre course.",
                      style: TextStyle(fontSize: 13, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text("OK, j'arrive !"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIX #3: Gérer la fin de course avec relecture des données depuis le serveur
  Future<void> _handleTripCompleted() async {
    if (_currentTripID == null) {
      _resetApp();
      return;
    }

    // Sauvegarder les IDs avant qu'ils ne soient effacés
    final tripId = _currentTripID!;
    final driverId = _driverID;

    // Relire les données du trip depuis le serveur pour avoir le montant final
    try {
      final tripData = await TripRequestService.getTripDetails(tripId);
      if (tripData != null) {
        final serverFare = tripData['fare_amount']?.toString() ?? '';
        if (serverFare.isNotEmpty && serverFare != '0') {
          _fareAmount = '$serverFare HTG';
        }
        // Mettre à jour distance/durée si disponibles
        final serverDistance = tripData['distance']?.toString();
        final serverDuration = tripData['duration']?.toString();
        if (serverDistance != null && serverDistance.isNotEmpty) _distance = serverDistance;
        if (serverDuration != null && serverDuration.isNotEmpty) _duration = serverDuration;
      }
    } catch (e) {
      print("⚠️ Erreur relecture trip: $e");
    }

    // Notification locale
    NotificationService.showTripCompletedNotification(
      fareAmount: _fareAmount.replaceAll(' HTG', ''),
    );

    // Afficher le dialog de paiement
    _currentTripID = tripId;
    _driverID = driverId;
    _showPaymentDialog();
  }

  // ✅ Tracking chauffeur en temps réel
  void _startDriverTracking(String driverID) {
    _driverTrackingService?.dispose();
    if (_pickupLatLng == null) return;

    _driverTrackingService = DriverTrackingService(
      driverId: driverID,
      pickupLocation: _pickupLatLng!,
      onPositionUpdate: (position) {
        if (!mounted) return;
        setState(() {
          _markers.removeWhere((m) => m.key == const Key("driver_tracking"));
          _markers.add(
            Marker(
              key: const Key("driver_tracking"),
              point: position,
              width: 48,
              height: 48,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.local_taxi, color: Colors.white, size: 24),
              ),
            ),
          );
        });
      },
      onETAUpdate: (eta, distanceKm) {
        if (!mounted) return;
        setState(() {
          _driverETA = eta;
          _driverDistanceKm = distanceKm;
        });
      },
    );

    _driverTrackingService!.startTracking();
  }

  // ✅ Monitoring réseau avec reconnexion automatique
  void _initNetworkMonitoring() {
    final networkService = NetworkService();
    networkService.initialize();
    _networkSubscription = networkService.statusStream.listen((status) {
      final wasOffline = _networkStatus != NetworkStatus.online;
      if (mounted) {
        setState(() => _networkStatus = status);
      }
      // ✅ Reconnexion auto : relancer les streams si on revient online
      if (wasOffline && status == NetworkStatus.online && mounted) {
        print("🔄 Reconnexion détectée, relance des streams...");
        _driversSubscription?.cancel();
        _listenToOnlineDrivers();
        // Relancer l'écoute du trip si un trip est actif
        if (_currentTripID != null && _tripStatus != 'ended' && _tripStatus != 'cancelled') {
          _listenToTripStatus(_currentTripID!);
        }
      }
    });
  }

  Future<void> _cancelTrip() async {
    if (_currentTripID == null) return;

    // ✅ Arrêter le timeout
    _timeoutService?.cancel();

    final success = await TripRequestService.cancelTrip(_currentTripID!);

    if (success) {
      _resetApp();
      _cMethods.displaySnackBar("Course annulée", context);
    }
  }

  // ✅ PAIEMENT & RATING
  Future<void> _showPaymentDialog() async {
    if (_currentTripID == null || _driverID == null) {
      print("❌ Trip ou Driver ID manquant pour le paiement");
      _resetApp();
      return;
    }

    if (!mounted) return;

    // Sauvegarder les IDs avant le dialog (ils pourraient être effacés)
    final savedTripID = _currentTripID!;
    final savedDriverID = _driverID!;
    final savedDriverName = _driverName;

    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDialogSupabase(
        fareAmount: _fareAmount.replaceAll(' HTG', ''),
        tripID: savedTripID,
        driverID: savedDriverID,
        driverName: savedDriverName,
        distance: _distance,
        duration: _duration,
      ),
    );

    if (result != null && result['paid'] == true) {
      // Restaurer les IDs pour le rating dialog
      _currentTripID = savedTripID;
      _driverID = savedDriverID;
      _driverName = savedDriverName;
      await _showRatingDialog();
    }
  }

  Future<void> _showRatingDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RatingDialogSupabase(
        tripID: _currentTripID!,
        driverID: _driverID!,
        driverName: _driverName,
      ),
    );

    // Reset après rating
    await Future.delayed(const Duration(milliseconds: 1000));
    _resetApp();
  }

// ✅ GÉRER RETOUR FAVORITES
  Future<void> _handleFavoriteResult(Map<String, dynamic> favoriteData) async {
    print("⭐ Favori sélectionné - calcul route...");

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      final pickupLatLng = LatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      final destinationLatLng = LatLng(
        double.parse(favoriteData['latitude'].toString()),
        double.parse(favoriteData['longitude'].toString()),
      );

      final OSRMRoute? routeData = await OSRMRoutingService.getRoute(
        pickupLatLng,
        destinationLatLng,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (routeData != null) {
        final List<LatLng> routePoints = routeData.geometry;
        final String distance = routeData.distanceText;
        final String duration = routeData.durationText;

        final distanceKm = routeData.distanceInKm;
        // ✅ Calcul centralisé avec réduction abonnement
        final fare = FareCalculator.calculate(
          distanceKm: distanceKm,
          discountPercentage: currentUserDiscount,
        );
        final fareAmount = "$fare HTG";

        setState(() {
          _pickupLatLng = pickupLatLng;
          _destinationLatLng = destinationLatLng;
          _pickupAddress = "Ma position";
          _destinationAddress = favoriteData['address'] ?? favoriteData['name'];

          _distance = distance;
          _duration = duration;
          _fareAmount = fareAmount;

          _polylines = [
            OSMMapService.createRoutePolyline(
              routePoints,
              color: AppColors.primary,
            ),
          ];

          _markers.removeWhere((m) =>
              m.key == const Key("pickUp") || m.key == const Key("dropOff"));

          _markers.add(
            Marker(
              key: const Key("pickUp"),
              point: pickupLatLng,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_on,
                color: Colors.green,
                size: 40,
              ),
            ),
          );

          _markers.add(
            Marker(
              key: const Key("dropOff"),
              point: destinationLatLng,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_on,
                color: Colors.red,
                size: 40,
              ),
            ),
          );

          OSMMapService.animateToBounds(
            _mapController,
            [pickupLatLng, destinationLatLng],
            padding: const EdgeInsets.all(70),
          );

          _searchContainerHeight = 0;
          _rideDetailsHeight = 320;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Favori sélectionné !"),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Erreur favori: $e");
      if (mounted) {
        Navigator.pop(context);
        _cMethods.displaySnackBar("Erreur: $e", context);
      }
    }
  }

  // ✅ GÉRER RETOUR SEARCH
  Future<void> _handleSearchResult(dynamic result) async {
    print("🔍 Destination sélectionnée: $result");

    if (!mounted) return;

    // ✅ CAS 1: Map retournée par SearchDestinationPage (nouveau format)
    if (result is Map<String, dynamic>) {
      // Vérifier si c'est le format de SearchDestinationPage
      if (result.containsKey('destination_location') &&
          result.containsKey('pickup_location')) {
        print("✅ Format SearchDestinationPage détecté");

        final pickupLatLng = result['pickup_location'] as LatLng;
        final destinationLatLng = result['destination_location'] as LatLng;
        final pickupAddress = result['pickup_address'] as String;
        final destinationAddress = result['destination_address'] as String;
        final distance = result['distance'] as String;
        final duration = result['duration'] as String;
        final fareAmount = result['fare_amount'] as String;
        final routePoints = result['route_points'] as List<LatLng>;

        // Mettre à jour l'état SANS recalculer (déjà fait par SearchDestinationPage)
        setState(() {
          _pickupLatLng = pickupLatLng;
          _destinationLatLng = destinationLatLng;
          _pickupAddress = pickupAddress;
          _destinationAddress = destinationAddress;
          _distance = distance;
          _duration = duration;
          _fareAmount = fareAmount;

          // Créer polyline avec les points de la route
          _polylines = [
            OSMMapService.createRoutePolyline(
              routePoints,
              color: AppColors.primary,
            ),
          ];

          // Supprimer anciens markers
          _markers.removeWhere((m) =>
              m.key == const Key("pickUp") || m.key == const Key("dropOff"));

          // Ajouter markers pickup et dropoff
          _markers.add(
            Marker(
              key: const Key("pickUp"),
              point: pickupLatLng,
              width: 40,
              height: 40,
              child:
                  const Icon(Icons.location_on, color: Colors.green, size: 40),
            ),
          );

          _markers.add(
            Marker(
              key: const Key("dropOff"),
              point: destinationLatLng,
              width: 40,
              height: 40,
              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
          );

          // Ajuster la carte pour afficher les deux points
          OSMMapService.animateToBounds(
            _mapController,
            [pickupLatLng, destinationLatLng],
            padding: const EdgeInsets.all(70),
          );

          // Masquer search container, afficher ride details
          _searchContainerHeight = 0;
          _rideDetailsHeight = 320;
        });

        print("✅ Route affichée: $distance, $duration, $fareAmount");

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Destination confirmée !"),
            backgroundColor: AppColors.success,
          ),
        );

        return; // ✅ IMPORTANT: Sortir ici
      }

      // ✅ CAS 2: Ancien format Map (avec latitude/longitude)
      print("📍 Format Map ancien détecté");

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      try {
        final currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );

        final pickupLatLng = LatLng(
          currentPosition.latitude,
          currentPosition.longitude,
        );

        // Chercher latitude/longitude dans différents formats possibles
        final latValue = result['latitude'] ?? result['lat'];
        final lngValue = result['longitude'] ?? result['lng'] ?? result['lon'];

        if (latValue == null || lngValue == null) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "❌ Coordonnées manquantes\nKeys: ${result.keys.join(', ')}",
                ),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        double lat;
        double lng;

        if (latValue is double) {
          lat = latValue;
        } else if (latValue is String) {
          lat = double.parse(latValue);
        } else if (latValue is int) {
          lat = latValue.toDouble();
        } else {
          throw Exception("Type latitude invalide: ${latValue.runtimeType}");
        }

        if (lngValue is double) {
          lng = lngValue;
        } else if (lngValue is String) {
          lng = double.parse(lngValue);
        } else if (lngValue is int) {
          lng = lngValue.toDouble();
        } else {
          throw Exception("Type longitude invalide: ${lngValue.runtimeType}");
        }

        final destinationLatLng = LatLng(lat, lng);
        final destinationAddress = result['address'] ??
            result['name'] ??
            result['display_name'] ??
            "Destination";

        // Calculer route avec OSRM
        final OSRMRoute? routeData = await OSRMRoutingService.getRoute(
          pickupLatLng,
          destinationLatLng,
        );

        if (!mounted) return;
        Navigator.pop(context);

        if (routeData != null) {
          final distanceKm = routeData.distanceInKm;
          // ✅ Calcul centralisé avec réduction abonnement
          final fare = FareCalculator.calculate(
            distanceKm: distanceKm,
            discountPercentage: currentUserDiscount,
          );

          setState(() {
            _pickupLatLng = pickupLatLng;
            _destinationLatLng = destinationLatLng;
            _pickupAddress = "Ma position";
            _destinationAddress = destinationAddress;
            _distance = routeData.distanceText;
            _duration = routeData.durationText;
            _fareAmount = "$fare HTG";

            _polylines = [
              OSMMapService.createRoutePolyline(
                routeData.geometry,
                color: AppColors.primary,
              ),
            ];

            _markers.removeWhere((m) =>
                m.key == const Key("pickUp") || m.key == const Key("dropOff"));

            _markers.add(
              Marker(
                key: const Key("pickUp"),
                point: pickupLatLng,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on,
                    color: Colors.green, size: 40),
              ),
            );

            _markers.add(
              Marker(
                key: const Key("dropOff"),
                point: destinationLatLng,
                width: 40,
                height: 40,
                child:
                    const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            );

            OSMMapService.animateToBounds(
              _mapController,
              [pickupLatLng, destinationLatLng],
              padding: const EdgeInsets.all(70),
            );

            _searchContainerHeight = 0;
            _rideDetailsHeight = 320;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Destination confirmée !"),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        print("❌ Erreur: $e");
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur: $e"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }

      return; // Sortir ici
    }

    // ✅ CAS 3: AddressModel (ancien format)
    if (result is AddressModel) {
      print("📍 Format AddressModel détecté");

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      try {
        final currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );

        final pickupLatLng = LatLng(
          currentPosition.latitude,
          currentPosition.longitude,
        );

        final lat = result.latitudePosition;
        final lng = result.longitudePosition;

        if (lat == null || lng == null) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "❌ Coordonnées manquantes dans AddressModel\n"
                  "Lat: $lat, Lng: $lng",
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }

        final destinationLatLng = LatLng(lat, lng);
        final destinationAddress = result.placeName ?? "Destination";

        final OSRMRoute? routeData = await OSRMRoutingService.getRoute(
          pickupLatLng,
          destinationLatLng,
        );

        if (!mounted) return;
        Navigator.pop(context);

        if (routeData != null) {
          final distanceKm = routeData.distanceInKm;
          // ✅ Calcul centralisé avec réduction abonnement
          final fare = FareCalculator.calculate(
            distanceKm: distanceKm,
            discountPercentage: currentUserDiscount,
          );

          setState(() {
            _pickupLatLng = pickupLatLng;
            _destinationLatLng = destinationLatLng;
            _pickupAddress = "Ma position";
            _destinationAddress = destinationAddress;
            _distance = routeData.distanceText;
            _duration = routeData.durationText;
            _fareAmount = "$fare HTG";

            _polylines = [
              OSMMapService.createRoutePolyline(
                routeData.geometry,
                color: AppColors.primary,
              ),
            ];

            _markers.removeWhere((m) =>
                m.key == const Key("pickUp") || m.key == const Key("dropOff"));

            _markers.add(
              Marker(
                key: const Key("pickUp"),
                point: pickupLatLng,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on,
                    color: Colors.green, size: 40),
              ),
            );

            _markers.add(
              Marker(
                key: const Key("dropOff"),
                point: destinationLatLng,
                width: 40,
                height: 40,
                child:
                    const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            );

            OSMMapService.animateToBounds(
              _mapController,
              [pickupLatLng, destinationLatLng],
              padding: const EdgeInsets.all(70),
            );

            _searchContainerHeight = 0;
            _rideDetailsHeight = 320;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Destination confirmée !"),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        print("❌ Erreur: $e");
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Erreur: $e"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }

      return;
    }

    // ✅ Format non reconnu
    print("❌ Format non reconnu: ${result.runtimeType}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Format invalide: ${result.runtimeType}"),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ✅ RESET APP
  void _resetApp() {
    // ✅ ANNULER TIMERS
    _searchTimer?.cancel();
    _tripStatusPollingTimer?.cancel();

    setState(() {
      _searchContainerHeight = 276;
      _rideDetailsHeight = 0;
      _driverDetailsHeight = 0;
      _isSearchingDriver = false;
      _isExpandingSearch = false;

      _distance = "";
      _duration = "";
      _fareAmount = "";
      _pickupLatLng = null;
      _destinationLatLng = null;
      _pickupAddress = "";
      _destinationAddress = "";

      _driverName = "";
      _driverPhone = "";
      _driverPhoto = "";
      _carDetails = "";
      _carNumber = "";
      _carPhoto = "";
      _carColor = "";
      _tripStatus = "";
      _currentTripID = null;
      _driverID = null;
      _searchAttempt = 0;
      _totalDriversNotified = 0;
      _searchStatus = "";
      _driverRatings = "5.0";
      _driverETA = null;
      _driverDistanceKm = null;

      // ✅ RESET RECHERCHE
      _driversNotified = 0;
      _currentSearchRadius = 5000;

      // ✅ RESET GUARD ACCEPTATION
      _tripAcceptedHandled = false;

      _polylines.clear();
      _markers.removeWhere(
          (m) => m.key == const Key("pickUp") || m.key == const Key("dropOff") || m.key == const Key("driver_tracking"));
    });

    _tripSubscription?.cancel();
    _tripStatusSubscription?.cancel();
    _driverTrackingService?.dispose();
    _driverTrackingService = null;
  }

  // ✅ CONTRÔLES CARTE
  void _centerOnUser() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0,
      );
    }
  }

  void _zoomIn() {
    final zoom = _mapController.camera.zoom + 1;
    _mapController.move(
      _mapController.camera.center,
      zoom.clamp(3.0, 19.0),
    );
  }

  void _zoomOut() {
    final zoom = _mapController.camera.zoom - 1;
    _mapController.move(
      _mapController.camera.center,
      zoom.clamp(3.0, 19.0),
    );
  }

  // ✅ Appeler le chauffeur
  Future<void> _callDriver() async {
    if (_driverPhone.isEmpty) {
      _cMethods.displaySnackBar("Numéro non disponible", context, isError: true);
      return;
    }
    final uri = Uri(scheme: 'tel', path: _driverPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          _cMethods.displaySnackBar("Impossible d'ouvrir le téléphone", context, isError: true);
        }
      }
    } catch (e) {
      print("❌ Erreur appel: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timeoutService?.cancel();
    _tripStatusSubscription?.cancel();
    _tripStatusPollingTimer?.cancel();
    _driversSubscription?.cancel();
    _driversPollingTimer?.cancel(); // ✅ Cleanup polling chauffeurs
    _tripSubscription?.cancel();
    _searchTimer?.cancel();
    _driverTrackingService?.dispose();
    _networkSubscription?.cancel();
    super.dispose();
  }

  // ========== BUILD WIDGETS ==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: const ModernDrawer(),
      body: Stack(
        children: [
          // Carte
          FlutterMap(
            mapController: _mapController,
            options: OSMMapService.createMapOptions(
              center: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude, _currentPosition!.longitude)
                  : haitiInitialPosition,
              zoom: 13.0,
              onMapReady: _onMapReady,
            ),
            children: [
              OSMMapService.createTileLayer(),
              PolylineLayer(polylines: _polylines),
              MarkerLayer(markers: [..._markers, ..._driverMarkers]),
            ],
          ),

          // ✅ Offline banner
          if (_networkStatus != NetworkStatus.online)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 60,
              right: 16,
              child: OfflineBanner(status: _networkStatus),
            ),

          // UI Overlay
          _buildMenuButton(),
          _buildSearchContainer(),

          // ✅ UI de recherche
          if (_isSearchingDriver)
            _buildSearchingDriverUI()
          else if (_rideDetailsHeight > 0)
            _buildRideDetails(),

          if (_driverDetailsHeight > 0) _buildDriverDetailsEnhanced(),

          _buildMapControls(),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    return Positioned(
      top: 50,
      left: 20,
      child: GestureDetector(
        onTap: () => _scaffoldKey.currentState?.openDrawer(),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.menu,
            color: AppColors.primary,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      right: 20,
      top: 230,
      child: Column(
        children: [
          _buildControlButton(
            icon: Icons.my_location,
            onTap: _centerOnUser,
            color: AppColors.success,
            size: 50,
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.add,
            onTap: _zoomIn,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          _buildControlButton(
            icon: Icons.remove,
            onTap: _zoomOut,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildSearchContainer() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _searchContainerHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: _searchContainerHeight > 0
            ? ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Où allez-vous ?",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSearchButton(),
                      const SizedBox(height: 16),
                      _buildQuickAccessRow(),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSearchButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SearchDestinationPage(),
          ),
        );

        if (result != null && mounted) {
          await _handleSearchResult(result); // ✅ AJOUTÉ
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.search, color: AppColors.textSecondary),
            SizedBox(width: 12),
            Text(
              "Rechercher une destination",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessRow() {
    return Column(
      children: [
        // Première ligne : Favoris, Travail, Récents
        Row(
          children: [
            Expanded(
              child: _buildQuickAccessButton(
                icon: Icons.star,
                label: "Favoris",
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FavoriteLocationsPageSupabase(),
                    ),
                  );

                  if (result != null && mounted) {
                    await _handleFavoriteResult(result);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAccessButton(
                icon: Icons.work,
                label: "Travail",
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const WorkLocationPageSupabase(),
                    ),
                  );

                  if (result != null && mounted) {
                    await _handleFavoriteResult(result);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickAccessButton(
                icon: Icons.history,
                label: "Récents",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RecentLocationsPageSupabase(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ✅ NOUVEAU : Bouton Urgence (pleine largeur)
        _buildEmergencyButton(),
      ],
    );
  }

  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ BOUTON URGENCE
  Widget _buildEmergencyButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const EmergencyPage(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12), // ✅ Au lieu de 14
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emergency,
              color: Colors.white,
              size: 22, // ✅ Au lieu de 24
            ),
            SizedBox(width: 10), // ✅ Au lieu de 12
            Text(
              "URGENCE", // ✅ Texte plus court
              style: TextStyle(
                fontSize: 13, // ✅ Au lieu de 14
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideDetails() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: _rideDetailsHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: _rideDetailsHeight > 0
            ? SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // En-tête
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Détails de la course",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _rideDetailsHeight = 0;
                              _searchContainerHeight = 276;
                              _polylines.clear();
                              _markers.removeWhere((m) =>
                                  m.key == const Key("pickUp") ||
                                  m.key == const Key("dropOff"));
                            });
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Itinéraire
                    _buildRouteInfo(),

                    const SizedBox(height: 20),

                    // Infos course
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoItem(
                            Icons.straighten,
                            "Distance",
                            _distance,
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: AppColors.border,
                          ),
                          _buildInfoItem(
                            Icons.access_time,
                            "Durée",
                            _duration,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Prix
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Prix estimé",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _fareAmount,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Avant le bouton "DEMANDER UNE COURSE"
                    if (_isSearchingDriver && _driversNotified > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active,
                                color: AppColors.info, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "$_driversNotified chauffeur${_driversNotified > 1 ? 's' : ''} notifié${_driversNotified > 1 ? 's' : ''}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (_isExpandingSearch)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.info,
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Bouton demander
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isSearchingDriver ? null : _requestRide,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: _isSearchingDriver
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    "Recherche...",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            : const Text(
                                "DEMANDER UNE COURSE",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 50,
              color: AppColors.textSecondary,
            ),
            Container(
              width: 14,
              height: 14,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),

        const SizedBox(width: 16),

        // Adresses
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Départ",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _pickupAddress,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              const Text(
                "Arrivée",
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _destinationAddress,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ✅ ENHANCED Driver details — DraggableScrollableSheet
  Widget _buildDriverDetailsEnhanced() {
    if (_driverDetailsHeight <= 0) return const SizedBox.shrink();

    return Positioned.fill(
      child: DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.75,
        snap: true,
        snapSizes: const [0.25, 0.45, 0.75],
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, -6),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                // ── Handle ──
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // ── Status badge ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatusBadge(),
                      if (_driverETA != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time, size: 16, color: AppColors.info),
                              const SizedBox(width: 4),
                              Text(
                                'ETA: $_driverETA',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppColors.info,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Status timeline ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: StatusTimeline(currentStatus: _tripStatus),
                ),

                const SizedBox(height: 16),

                // ── Driver info ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                          image: _driverPhoto.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(_driverPhoto),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          color: _driverPhoto.isEmpty
                              ? AppColors.primary.withOpacity(0.1)
                              : null,
                        ),
                        child: _driverPhoto.isEmpty
                            ? const Icon(Icons.person, size: 32, color: AppColors.primary)
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _driverName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                ...List.generate(5, (i) {
                                  final rating = double.tryParse(_driverRatings) ?? 5.0;
                                  return Icon(
                                    i < rating.floor()
                                        ? Icons.star
                                        : (i < rating ? Icons.star_half : Icons.star_border),
                                    color: AppColors.warning,
                                    size: 16,
                                  );
                                }),
                                const SizedBox(width: 4),
                                Text(
                                  _driverRatings,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            if (_driverDistanceKm != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.near_me, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_driverDistanceKm!.toStringAsFixed(1)} km',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Vehicle info ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.directions_car, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _carDetails.isNotEmpty ? _carDetails : 'Véhicule',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              if (_carColor.isNotEmpty)
                                Text(
                                  _carColor,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _carNumber,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Fare breakdown (during active trip only) ──
                if (_tripStatus == 'ontrip' && _distance.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FareBreakdown(
                      distanceKm: double.tryParse(_distance.replaceAll(' km', '').replaceAll(' m', '')) ?? 0,
                      trafficLabel: OSRMRoutingService.getTrafficEstimation().label,
                      trafficMultiplier: OSRMRoutingService.getTrafficEstimation().multiplier,
                      discountPercentage: currentUserDiscount,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Action buttons ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _buildDetailActionBtn(Icons.phone, 'Appeler', AppColors.success, _callDriver)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailActionBtn(Icons.chat_bubble_outline, 'Message', AppColors.primary, () {
                          if (_currentTripID != null && _driverID != null) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => TripChatPage(
                                tripId: _currentTripID!,
                                driverName: _driverName,
                                driverPhoto: _driverPhoto,
                              ),
                            ));
                          }
                        }),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDetailActionBtn(Icons.emergency, 'Urgence', AppColors.error, () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyPage()));
                        }),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Share trip ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (_) => TripShareSheet(
                            driverName: _driverName,
                            carDetails: _carDetails,
                            carNumber: _carNumber,
                            pickupAddress: _pickupAddress,
                            destinationAddress: _destinationAddress,
                            fareAmount: _fareAmount,
                            eta: _driverETA ?? _duration,
                          ),
                        );
                      },
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Partager ma course'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.info,
                        side: const BorderSide(color: AppColors.info),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),

                // ── Cancel button ──
                if (_tripStatus != 'ended' && _tripStatus != 'completed') ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Annuler la course ?"),
                              content: const Text("Êtes-vous sûr de vouloir annuler cette course ?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("Non"),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _cancelTrip();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text("Oui, annuler"),
                                ),
                              ],
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'ANNULER LA COURSE',
                          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Badge de statut coloré
  Widget _buildStatusBadge() {
    String text;
    Color color;
    switch (_tripStatus) {
      case 'accepted':
        text = 'Chauffeur en route';
        color = AppColors.info;
        break;
      case 'arrived':
        text = 'Chauffeur arrivé';
        color = AppColors.warning;
        break;
      case 'ontrip':
        text = 'Course en cours';
        color = AppColors.success;
        break;
      case 'ended':
      case 'completed':
        text = 'Course terminée';
        color = AppColors.primary;
        break;
      default:
        text = 'En attente';
        color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton d'action (Appeler, Message, Urgence)
  Widget _buildDetailActionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchingDriverUI() {
    final isFound = _tripStatus == 'found';
    final progress = isFound ? 1.0 : (_searchAttempt / 3).clamp(0.0, 1.0);
    final currentRadius = _timeoutService?.currentRadius ?? 5000;
    final radiusKm = (currentRadius / 1000).toStringAsFixed(1);

    // Couleurs selon l'état
    final progressColor = isFound
        ? AppColors.success
        : (_searchAttempt >= 2 ? AppColors.warning : AppColors.primary);

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: isFound
                  ? AppColors.success.withOpacity(0.2)
                  : Colors.black12,
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ HANDLE
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isFound ? AppColors.success : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const SizedBox(height: 24),

                // ✅ ANIMATION + ICÔNE (change selon l'état)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) => ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                  child: isFound
                      ? _buildFoundIndicator()
                      : _buildSearchingIndicator(progress, progressColor),
                ),

                const SizedBox(height: 24),

                // ✅ TITRE DYNAMIQUE
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isFound
                        ? "Chauffeur trouvé ✓"
                        : (_searchAttempt == 1
                            ? "Recherche de chauffeurs..."
                            : "Élargissement de la recherche..."),
                    key: ValueKey(isFound ? 'found' : 'searching_$_searchAttempt'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isFound ? AppColors.success : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),

                // ✅ STATUT
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _searchStatus,
                    key: ValueKey(_searchStatus),
                    style: TextStyle(
                      fontSize: 14,
                      color: isFound ? AppColors.success : Colors.grey.shade600,
                      fontWeight: isFound ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // ✅ Ne pas afficher les statistiques et boutons si chauffeur trouvé
                if (!isFound) ...[
                  const SizedBox(height: 24),

                  // ✅ CARTE STATISTIQUES
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.1),
                          AppColors.primary.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard(
                              Icons.people_outline,
                              "Chauffeurs\nnotifiés",
                              "$_totalDriversNotified",
                              AppColors.success,
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color: Colors.grey.shade300,
                            ),
                            _buildStatCard(
                              Icons.radar,
                              "Rayon de\nrecherche",
                              "$radiusKm km",
                              AppColors.info,
                            ),
                          ],
                        ),
                        if (_searchAttempt > 1) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Recherche élargie automatiquement",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ✅ BOUTONS D'ACTION
                  Row(
                    children: [
                      // Bouton Élargir maintenant
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _searchAttempt >= 3
                              ? null
                              : () async {
                                  setState(() {
                                    _searchStatus = "Élargissement manuel...";
                                  });
                                  await _timeoutService
                                      ?.expandSearchManually();
                                },
                          icon: const Icon(Icons.zoom_out_map, size: 20),
                          label: const Text(
                            "Élargir\nmaintenant",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.info,
                            side: BorderSide(
                              color: _searchAttempt >= 3
                                  ? Colors.grey.shade300
                                  : AppColors.info,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Bouton Annuler
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCancelConfirmation(),
                          icon: const Icon(Icons.close, size: 20),
                          label: const Text("Annuler la recherche"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ✅ TIMER VISUEL (optionnel)
                  if (_searchAttempt < 3)
                    Text(
                      "Élargissement automatique dans ~${20 - (_searchAttempt * 3)}s",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                ],

                // ✅ Indicateur "Préparation du suivi..." si trouvé
                if (isFound) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.success.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Préparation du suivi...",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Indicateur visuel : Recherche en cours (cercle + loupe)
  Widget _buildSearchingIndicator(double progress, Color color) {
    return Stack(
      key: const ValueKey('searching_indicator'),
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        Column(
          children: [
            Icon(Icons.search, size: 40, color: color),
            const SizedBox(height: 4),
            Text(
              "$_searchAttempt/3",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Indicateur visuel : Chauffeur trouvé ✓ (cercle vert + check)
  Widget _buildFoundIndicator() {
    return Container(
      key: const ValueKey('found_indicator'),
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.success.withOpacity(0.1),
        border: Border.all(color: AppColors.success, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.check,
        size: 60,
        color: AppColors.success,
      ),
    );
  }

// ✅ WIDGET STATISTIQUE AMÉLIORÉ
  Widget _buildStatCard(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

