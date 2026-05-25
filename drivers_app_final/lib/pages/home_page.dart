import 'dart:async';
import 'package:drivers_app/services/foreground_location_service.dart';
import 'package:drivers_app/services/local_notification_service.dart';
import 'package:drivers_app/services/push_notification_system.dart';
import 'package:drivers_app/services/app_settings_service.dart';
import 'package:drivers_app/services/osm_map_service.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/models/trip_details.dart';
import 'package:drivers_app/widgets/notification_dialog.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../global/global_var.dart';
import '../theme/app_colors.dart';
import 'dashboard.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with AutomaticKeepAliveClientMixin<HomePage>, TickerProviderStateMixin, WidgetsBindingObserver {
  final MapController _mapController = MapController();

  Position? _currentPosition;
  final PushNotificationSystem _notificationSystem = PushNotificationSystem();

  bool _isLoading = true;
  bool _isDriverOnline = false;
  int _onlineDuration = 0;
  Timer? _onlineTimer;
  StreamSubscription<Position>? _positionSubscription;

  // ✅ Supabase Realtime channels
  RealtimeChannel? _tripRequestChannel;
  RealtimeChannel? _paymentNotificationChannel;
  RealtimeChannel? _tripCancellationChannel;
  RealtimeChannel? _adminMessageChannel;
  RealtimeChannel? _appSettingsChannel;

  LatLng? _driverPosition;
  final List<Marker> _markers = [];

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initAnimations();
    _initializeDriver();
  }

  // ============================================================
  // ✅ APP LIFECYCLE — reconnecter quand l'app revient au premier plan
  // ============================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print("📱 App revenue au premier plan");
        // Re-souscrire aux channels Realtime si nécessaire
        if (_isDriverOnline) {
          _subscribeToNewTrips();
          _subscribeToTripCancellations();
        }
        _listenForPaymentNotifications();
        _subscribeToAdminMessages();
        _subscribeToAppSettings();
        break;

      case AppLifecycleState.paused:
        print("📱 App en arrière-plan");
        break;

      case AppLifecycleState.detached:
        print("📱 App détachée");
        _cleanupAllChannels();
        break;

      default:
        break;
    }
  }

  // ============================================================
  // ✅ INITIALISATION
  // ============================================================

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineTimer?.cancel();
    _positionSubscription?.cancel();
    _cleanupAllChannels();
    ForegroundLocationService.stopForegroundNotification();
    _pulseController.dispose();
    super.dispose();
  }

  /// Nettoyer tous les channels Realtime
  void _cleanupAllChannels() {
    _tripRequestChannel?.unsubscribe();
    _tripRequestChannel = null;
    _paymentNotificationChannel?.unsubscribe();
    _paymentNotificationChannel = null;
    _tripCancellationChannel?.unsubscribe();
    _tripCancellationChannel = null;
    _adminMessageChannel?.unsubscribe();
    _adminMessageChannel = null;
    _appSettingsChannel?.unsubscribe();
    _appSettingsChannel = null;
  }

  Future<void> _initializeDriver() async {
    await _loadDriverInfo();
    await _checkLocationPermission();
    await _loadLastStatus();
    await _initializeNotifications();
    _listenForPaymentNotifications();
    _subscribeToAdminMessages();
    _subscribeToAppSettings();
  }

  // ============================================================
  // ✅ NOTIFICATIONS — FCM + Supabase Realtime
  // ============================================================

  Future<void> _initializeNotifications() async {
    await _notificationSystem.initialize();

    // ✅ Écouter les notifications FCM (tous les 3 canaux)
    _notificationSystem.startListeningForNewNotification(context);

    print("✅ Système de notifications initialisé");
  }

  /// ✅ Souscrire aux nouvelles demandes de course via Supabase Realtime
  void _subscribeToNewTrips() {
    // Éviter les doublons
    _tripRequestChannel?.unsubscribe();

    final userId = SupabaseService.getCurrentUser()?.id;
    if (userId == null) return;

    print("🎧 Écoute Realtime nouvelles courses activée");

    _tripRequestChannel = SupabaseService.subscribeToAvailableTrips(
      onNewTrip: (tripData) async {
        if (!mounted) return;

        print("🔔 Nouvelle course détectée via Realtime!");

        final tripId = tripData['trip_id']?.toString();
        final pickupAddress = tripData['pickup_address']?.toString() ?? 'Adresse inconnue';
        final userName = tripData['user_name']?.toString() ?? 'Client';

        // ✅ Afficher une notification locale système
        await LocalNotificationService.showTripNotification(
          tripId: tripId ?? '',
          pickupAddress: pickupAddress,
          userName: userName,
        );

        // ✅ Afficher le dialog dans l'app
        if (mounted && tripId != null) {
          _showTripRequestDialog(tripId, tripData);
        }
      },
    );
  }

  /// Afficher le dialog de demande de course
  void _showTripRequestDialog(String tripId, Map<String, dynamic> tripData) {
    if (!mounted) return;

    TripDetails tripDetailsInfo = TripDetails.fromSupabase(tripData);
    tripDetailsInfo.tripID = tripId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => NotificationDialog(
        tripDetailsInfo: tripDetailsInfo,
      ),
    );
  }

  /// ✅ Souscrire aux annulations de course
  void _subscribeToTripCancellations() {
    _tripCancellationChannel?.unsubscribe();

    final userId = SupabaseService.getCurrentUser()?.id;
    if (userId == null) return;

    _tripCancellationChannel = SupabaseService.subscribeToTripCancellation(
      driverId: userId,
      onTripCancelled: (tripData) async {
        if (!mounted) return;

        final userName = tripData['user_name']?.toString() ?? 'Client';
        final tripId = tripData['trip_id']?.toString() ?? '';

        print("❌ Course annulée par le client: $tripId");

        // Notification locale
        await LocalNotificationService.showTripCancelledNotification(
          tripId: tripId,
          userName: userName,
        );

        // SnackBar dans l'app
        if (mounted) {
          _showSnackBar("$userName a annulé la course", isError: true);
        }
      },
    );
  }

  /// ✅ Écouter les confirmations de paiement
  void _listenForPaymentNotifications() {
    _paymentNotificationChannel?.unsubscribe();

    final userId = SupabaseService.getCurrentUser()?.id;
    if (userId == null) return;

    print("🎧 Écoute notifications paiement pour: $userId");

    _paymentNotificationChannel = Supabase.instance.client
        .channel('payment_notifications_$userId')
        .onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'trip_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'driver_id',
        value: userId,
      ),
      callback: (payload) async {
        if (!mounted) return;

        final data = payload.newRecord;

        if (data['payment_status'] == 'confirmed') {
          print("🔔 Notification paiement reçue!");

          final tripId = data['trip_id']?.toString() ?? '';
          final fareAmount = data['fare_amount']?.toString() ?? "0";

          // Notification locale système
          await LocalNotificationService.showPaymentNotification(
            tripId: tripId,
            amount: fareAmount,
          );

          if (mounted) {
            _showPaymentConfirmedDialog(
              tripId: tripId,
              fareAmount: fareAmount,
            );
          }
        }
      },
    ).subscribe();
  }

  void _showPaymentConfirmedDialog({
    required String tripId,
    required String fareAmount,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
            ),
            const SizedBox(height: 20),
            const Text('Paiement Confirmé', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('$fareAmount HTG', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 10),
            const Text('Le client a confirmé le paiement', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const Dashboard()),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retour au Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ ADMIN MESSAGES & SETTINGS — WebSocket Realtime
  // ============================================================

  /// Écouter les messages/annonces admin en temps réel
  void _subscribeToAdminMessages() {
    _adminMessageChannel?.unsubscribe();

    _adminMessageChannel = SupabaseService.subscribeToAdminMessages(
      onNewMessage: (msgData) async {
        if (!mounted) return;

        final title = msgData['title']?.toString() ?? 'Message admin';
        final message = msgData['message']?.toString() ?? '';

        print("📢 Message admin reçu: $title");

        // Notification locale
        await LocalNotificationService.showNotification(
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
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
      },
    );
    print("🎧 Écoute messages admin activée");
  }

  /// Écouter les changements de tarification en temps réel
  void _subscribeToAppSettings() {
    _appSettingsChannel?.unsubscribe();

    _appSettingsChannel = SupabaseService.subscribeToAppSettings(
      onSettingsChanged: (settings) async {
        if (!mounted) return;

        print("💰 Mise à jour tarification reçue via WebSocket");

        // Recharger les paramètres dans AppSettingsService
        await AppSettingsService.refresh();

        if (mounted) {
          _showSnackBar(
            "💰 Tarifs mis à jour: ${AppSettingsService.pricePerKm} HTG/km",
          );
        }
      },
    );
    print("🎧 Écoute tarification activée");
  }

  // ============================================================
  // ✅ DRIVER INFO & LOCATION
  // ============================================================

  Future<void> _loadDriverInfo() async {
    final userId = SupabaseService.getCurrentUser()?.id;
    if (userId == null) return;

    try {
      final profile = await SupabaseService.getDriverProfile(userId);

      if (profile != null) {
        setState(() {
          driverId = profile['id'] ?? '';
          driverName = profile['name'] ?? "";
          driverPhone = profile['phone'] ?? "";
          driverPhoto = profile['photo'] ?? "";
          driverEmail = profile['email'] ?? "";
          carModel = profile['car_model'] ?? "";
          carColor = profile['car_color'] ?? "";
          carNumber = profile['car_number'] ?? "";
          carYear = profile['car_year'] ?? "";
        });
      }
    } catch (e) {
      print("❌ Erreur chargement info: $e");
    }
  }

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _isLoading = false);
      _showSnackBar("Service de localisation désactivé", isError: true);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _isLoading = false);
        _showSnackBar("Permission de localisation refusée", isError: true);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => _isLoading = false);
      _showSnackBar("Permission refusée définitivement", isError: true);
      return;
    }

    await _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        currentPosition = position;
        driverCurrentPosition = position;
        _driverPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _addDriverMarker();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _centerMapOnDriver();
        });
      });
    } catch (e) {
      print("❌ Erreur position: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLastStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final wasOnline = prefs.getBool('driver_online') ?? false;

    if (wasOnline) {
      await _goOnline();
    }
  }

  // ============================================================
  // ✅ ONLINE / OFFLINE
  // ============================================================

  Future<void> _goOnline() async {
    if (_currentPosition == null) {
      _showSnackBar("Position non disponible", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await SupabaseService.updateDriverLocation(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
      );

      final success = await SupabaseService.toggleAvailability(true);

      if (success) {
        setState(() {
          _isDriverOnline = true;
          isDriverCurrentlyOnline = true;
          _isLoading = false;
        });

        _startOnlineTimer();
        _startLocationTracking();
        _saveOnlineStatus(true);
        _addDriverMarker();

        // ✅ Activer l'écoute Realtime des nouvelles courses
        _subscribeToNewTrips();
        _subscribeToTripCancellations();

        // ✅ Démarrer la notification persistante (GPS en arrière-plan)
        await ForegroundLocationService.startForegroundNotification();

        _showSnackBar("Vous êtes maintenant EN LIGNE");
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("Erreur: Impossible de passer en ligne", isError: true);
      }
    } catch (e) {
      print("❌ Erreur _goOnline: $e");
      setState(() => _isLoading = false);
      _showSnackBar("Erreur: $e", isError: true);
    }
  }

  Future<void> _goOffline() async {
    setState(() => _isLoading = true);

    try {
      final success = await SupabaseService.toggleAvailability(false);

      if (success) {
        setState(() {
          _isDriverOnline = false;
          isDriverCurrentlyOnline = false;
          _onlineDuration = 0;
          _isLoading = false;
        });

        _stopOnlineTimer();
        _stopLocationTracking();
        _saveOnlineStatus(false);
        _addDriverMarker();

        // ✅ Arrêter l'écoute Realtime des courses
        _tripRequestChannel?.unsubscribe();
        _tripRequestChannel = null;
        _tripCancellationChannel?.unsubscribe();
        _tripCancellationChannel = null;

        // ✅ Arrêter la notification persistante
        await ForegroundLocationService.stopForegroundNotification();

        _showSnackBar("Vous êtes maintenant HORS LIGNE");
      } else {
        setState(() => _isLoading = false);
        _showSnackBar("Erreur: Impossible de passer hors ligne", isError: true);
      }
    } catch (e) {
      print("❌ Erreur _goOffline: $e");
      setState(() => _isLoading = false);
      _showSnackBar("Erreur: $e", isError: true);
    }
  }

  // ============================================================
  // ✅ TIMERS & TRACKING
  // ============================================================

  void _startOnlineTimer() {
    _onlineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _onlineDuration++);
    });
  }

  void _stopOnlineTimer() {
    _onlineTimer?.cancel();
    _onlineTimer = null;
  }

  void _startLocationTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      setState(() {
        _currentPosition = position;
        currentPosition = position;
        driverCurrentPosition = position;
        _driverPosition = LatLng(position.latitude, position.longitude);
      });

      _addDriverMarker();

      try {
        _centerMapOnDriver();
      } catch (e) {
        // Ignore si carte pas prête
      }

      await SupabaseService.updateDriverLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
  }

  void _stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  Future<void> _saveOnlineStatus(bool isOnline) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('driver_online', isOnline);
  }

  // ============================================================
  // ✅ MAP & MARKERS
  // ============================================================

  void _addDriverMarker() {
    if (_driverPosition == null) return;

    setState(() {
      _markers.clear();
      _markers.add(
        Marker(
          point: _driverPosition!,
          width: 70,
          height: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isDriverOnline
                        ? AppColors.primary.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isDriverOnline ? AppColors.primary : Colors.grey,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.local_taxi, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _centerMapOnDriver() {
    if (_driverPosition != null) {
      try {
        _mapController.move(_driverPosition!, 15.0);
      } catch (e) {
        print('ℹ️ Carte pas encore prête pour centrer');
      }
    }
  }

  // ============================================================
  // ✅ UI HELPERS
  // ============================================================

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  // ============================================================
  // ✅ BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: Stack(
        children: [
          // ✅ Carte OSM
          _isLoading
              ? const Center(
            child: SpinKitFadingCircle(color: AppColors.primary, size: 50.0),
          )
              : FlutterMap(
            mapController: _mapController,
            options: OSMMapService.createMapOptions(
              center: _driverPosition ?? const LatLng(18.5944, -72.3074),
              zoom: 15.0,
            ),
            children: [
              OSMMapService.createTileLayer(),
              MarkerLayer(markers: _markers),
            ],
          ),

          // ✅ Status Card moderne avec bouton intégré
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: _buildModernStatusCard(),
          ),

          // ✅ Boutons de zoom modernes (droite)
          Positioned(
            right: 16,
            top: 180,
            child: _buildZoomControls(),
          ),

          // ✅ Bouton centrer sur position
          Positioned(
            right: 16,
            top: 300,
            child: _buildCenterButton(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ✅ WIDGETS
  // ============================================================

  Widget _buildModernStatusCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDriverOnline
              ? isDark
                  ? [const Color(0xFF1F2937), const Color(0xFF064E3B)]
                  : [Colors.white, Colors.green.shade50]
              : isDark
                  ? [const Color(0xFF1F2937), const Color(0xFF374151)]
                  : [Colors.white, Colors.grey.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isDriverOnline
                        ? Colors.green.withOpacity(isDark ? 0.2 : 0.15)
                        : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    border: Border.all(
                      color: _isDriverOnline ? Colors.green : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.person,
                    color: _isDriverOnline ? Colors.green.shade700 : Colors.grey.shade600,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName.isNotEmpty ? driverName : "Chauffeur",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isDriverOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isDriverOnline
                                ? _formatDuration(_onlineDuration)
                                : "Hors ligne",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _isDriverOnline ? Colors.green.shade700 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () async {
              if (_isDriverOnline) {
                await _goOffline();
              } else {
                await _goOnline();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 60,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: _isDriverOnline
                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                      : [Colors.grey.shade400, Colors.grey.shade500],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isDriverOnline ? const Color(0xFF10B981) : Colors.grey.shade400)
                        .withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    left: _isDriverOnline ? 30 : 2,
                    top: 2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isDriverOnline ? Icons.check : Icons.close,
                        size: 16,
                        color: _isDriverOnline ? Colors.green : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomControls() {
    return Column(
      children: [
        _buildMapButton(
          icon: Icons.add,
          onTap: () {
            final currentZoom = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, currentZoom + 1);
          },
        ),
        const SizedBox(height: 8),
        _buildMapButton(
          icon: Icons.remove,
          onTap: () {
            final currentZoom = _mapController.camera.zoom;
            _mapController.move(_mapController.camera.center, currentZoom - 1);
          },
        ),
      ],
    );
  }

  Widget _buildCenterButton() {
    return _buildMapButton(
      icon: Icons.my_location,
      onTap: _centerMapOnDriver,
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
        ),
      ),
    );
  }
}