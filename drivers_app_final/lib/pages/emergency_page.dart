import 'dart:async';
import 'package:drivers_app/global/global_var.dart';
import 'package:drivers_app/services/osm_map_service.dart';
import 'package:drivers_app/services/osrm_routing_service.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/theme/app_colors.dart';
import 'package:drivers_app/widgets/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// 🚨 Page de navigation GPS vers le client en urgence
class EmergencyPage extends StatefulWidget {
  final Map<String, dynamic> emergencyData;

  const EmergencyPage({super.key, required this.emergencyData});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  final MapController _mapController = MapController();

  // Position
  LatLng? _driverPosition;
  LatLng? _clientPosition;
  List<LatLng> _routePoints = [];

  // Marqueurs
  List<Marker> _markers = [];

  // Info trajet
  String _distanceText = "Calcul...";
  String _durationText = "Calcul...";
  String _status = "en_route"; // en_route, arrived, resolved

  // Tracking
  StreamSubscription<Position>? _positionStream;
  bool _isLoading = true;

  String get _userName =>
      widget.emergencyData['user_name']?.toString() ?? 'Client';

  String get _userPhone =>
      widget.emergencyData['user_phone']?.toString() ?? '';

  String get _emergencyId =>
      widget.emergencyData['id']?.toString() ?? '';

  String get _message =>
      widget.emergencyData['message']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _initializeEmergency();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _initializeEmergency() async {
    // Position du client
    final lat = widget.emergencyData['latitude'];
    final lng = widget.emergencyData['longitude'];
    if (lat != null && lng != null) {
      _clientPosition = LatLng(
        (lat as num).toDouble(),
        (lng as num).toDouble(),
      );
    }

    // Position actuelle du chauffeur
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _driverPosition = LatLng(position.latitude, position.longitude);
    } catch (e) {
      print("❌ Erreur position: $e");
      if (driverCurrentPosition != null) {
        _driverPosition = LatLng(
          driverCurrentPosition!.latitude,
          driverCurrentPosition!.longitude,
        );
      }
    }

    // Calculer la route
    if (_driverPosition != null && _clientPosition != null) {
      await _calculateRoute();
    }

    // Démarrer le tracking GPS
    _startLocationTracking();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _calculateRoute() async {
    if (_driverPosition == null || _clientPosition == null) return;

    try {
      final route = await OSRMRoutingService.getRoute(
        _driverPosition!,
        _clientPosition!,
      );

      if (route != null && mounted) {
        setState(() {
          _routePoints = route.geometry;
          _distanceText = route.distanceText;
          _durationText = route.durationText;

          _markers = [
            OSMMapService.createDriverMarker(_driverPosition!),
            Marker(
              point: _clientPosition!,
              width: 50,
              height: 50,
              child: const Column(
                children: [
                  Icon(Icons.emergency, color: Colors.red, size: 36),
                  Text(
                    "SOS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ];
        });

        // Ajuster la vue de la carte
        final bounds =
            OSMMapService.calculateBounds([_driverPosition!, _clientPosition!]);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)),
        );
            }
    } catch (e) {
      print("❌ Erreur calcul route urgence: $e");
    }
  }

  void _startLocationTracking() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _driverPosition = LatLng(position.latitude, position.longitude);
        });

        // Mettre à jour la position dans Supabase
        SupabaseService.updateDriverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
        );

        // Recalculer la route périodiquement
        _calculateRoute();
      }
    });
  }

  Future<void> _callClient() async {
    if (_userPhone.isEmpty) {
      SnackBarHelper.showWarning(context, "Numéro non disponible");
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: _userPhone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _markArrived() async {
    setState(() => _status = "arrived");

    // On ne change pas le status dans la DB ici, juste l'UI locale
    SnackBarHelper.showSuccess(context, "Vous êtes arrivé !");
  }

  Future<void> _resolveEmergency() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Résoudre l'urgence ?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Confirmez que la situation d'urgence a été résolue et que le client est en sécurité.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Fermer le dialog

              final success =
                  await SupabaseService.resolveEmergency(_emergencyId);

              if (success && mounted) {
                // Afficher le dialog de succès
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => _buildResolvedDialog(),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Confirmer"),
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.success, Color(0xFF059669)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Urgence Résolue !",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Merci d'avoir aidé $_userName.\nVotre intervention a fait la différence !",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Fermer le dialog
                  Navigator.pop(context); // Retour au dashboard
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "RETOUR À L'ACCUEIL",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.error),
                  SizedBox(height: 16),
                  Text(
                    "Calcul de l'itinéraire d'urgence...",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Carte
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _driverPosition ?? const LatLng(18.5, -72.3),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.lebontaxi.driver',
                    ),
                    if (_routePoints.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5.0,
                            color: AppColors.error,
                          ),
                        ],
                      ),
                    MarkerLayer(markers: _markers),
                  ],
                ),

                // Header urgence
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      right: 16,
                      bottom: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.error, AppColors.errorDark],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            // Confirmer avant de quitter
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Quitter l'urgence ?"),
                                content: const Text(
                                  "Le client attend votre aide. Êtes-vous sûr de vouloir quitter ?",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Rester"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error,
                                    ),
                                    child: const Text("Quitter"),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                        ),
                        const Expanded(
                          child: Text(
                            "🚨 INTERVENTION D'URGENCE",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Equilibre le bouton retour
                      ],
                    ),
                  ),
                ),

                // Info Card en bas
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomCard(),
                ),
              ],
            ),
    );
  }

  Widget _buildBottomCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 16),

              // Status chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _status == "arrived"
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _status == "arrived"
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _status == "arrived"
                          ? "Arrivé sur place"
                          : "En route vers le client",
                      style: TextStyle(
                        color: _status == "arrived"
                            ? AppColors.success
                            : AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Distance & Durée
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _durationText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                        width: 1, height: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 12),
                    const Icon(Icons.route,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _distanceText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Client info
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person,
                        color: AppColors.error, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Client en détresse",
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bouton appeler
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _callClient,
                      icon: const Icon(Icons.phone, color: AppColors.success),
                    ),
                  ),
                ],
              ),

              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.message,
                          size: 16, color: AppColors.error.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _message,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Bouton d'action
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _status == "en_route"
                      ? _markArrived
                      : _resolveEmergency,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _status == "en_route"
                        ? AppColors.warning
                        : AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _status == "en_route"
                        ? "JE SUIS ARRIVÉ"
                        : "URGENCE RÉSOLUE ✓",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
