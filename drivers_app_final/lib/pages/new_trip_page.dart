import 'dart:async';
import 'package:drivers_app/methods/common_methods.dart';
import 'package:drivers_app/models/trip_details.dart';
import 'package:drivers_app/services/osm_map_service.dart';
import 'package:drivers_app/services/osrm_routing_service.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/widgets/payment_dialog.dart';
import 'package:drivers_app/widgets/trip_progress_card.dart';
import 'package:drivers_app/pages/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../global/global_var.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_dialog.dart';

class NewTripPage extends StatefulWidget {
  final TripDetails? newTripDetailsInfo;

  const NewTripPage({super.key, this.newTripDetailsInfo});

  @override
  State<NewTripPage> createState() => _NewTripPageState();
}

class _NewTripPageState extends State<NewTripPage> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  StreamSubscription<Position>? positionStreamNewTripPage;

  List<Marker> markers = [];
  List<Polyline> polylines = [];
  List<LatLng> routePoints = [];

  bool directionRequested = false;
  String statusOfTrip = "accepted";
  String durationText = "", distanceText = "";
  String buttonTitleText = "ARRIVÉ";
  Color buttonColor = AppColors.success;
  CommonMethods cMethods = CommonMethods();

  LatLng? driverPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() => _mapReady = true);
      _initializeTrip();
    });
  }

  @override
  void dispose() {
    positionStreamNewTripPage?.cancel();
    super.dispose();
  }

  Future<void> _initializeTrip() async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (driverCurrentPosition != null) {
      driverPosition = LatLng(
        driverCurrentPosition!.latitude,
        driverCurrentPosition!.longitude,
      );
    }

    _addPickupAndDropoffMarkers();

    await _obtainDirectionAndDrawRoute(
      driverPosition ?? widget.newTripDetailsInfo!.pickUpLatLng!,
      widget.newTripDetailsInfo!.pickUpLatLng!,
    );

    _getLiveLocationUpdatesOfDriver();

    /// ✅ Sauvegarder les infos du chauffeur (Supabase)
    await _saveDriverDataToTripInfo();
  }

  void _addPickupAndDropoffMarkers() {
    markers.add(
      OSMMapService.createPickupMarker(
        widget.newTripDetailsInfo!.pickUpLatLng!,
      ),
    );

    markers.add(
      OSMMapService.createDropoffMarker(
        widget.newTripDetailsInfo!.dropOffLatLng!,
      ),
    );

    setState(() {});
  }

  Future<void> _obtainDirectionAndDrawRoute(
      LatLng source, LatLng destination) async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) =>
      const LoadingDialog(messageText: 'Calcul de l\'itinéraire...'),
    );

    try {
      final route = await OSRMRoutingService.getRoute(source, destination);

      if (!mounted) return;
      Navigator.pop(context);

      if (route == null) {
        _showSnackBar("Impossible de calculer l'itinéraire", isError: true);
        return;
      }

      routePoints = route.geometry;
      durationText = route.durationText;
      distanceText = route.distanceText;

      polylines.clear();
      polylines.add(
        OSMMapService.createRoutePolyline(
          routePoints,
          color: AppColors.primary,
        ),
      );

      if (_mapReady) {
        try {
          OSMMapService.animateToBounds(
            _mapController,
            [source, destination],
          );
        } catch (e) {
          print("⚠️ Carte pas encore prête, zoom manuel");
          _mapController.move(source, 14.0);
        }
      }

      setState(() {});
    } catch (e) {
      if (mounted) Navigator.pop(context);
      print("❌ Erreur calcul route: $e");
      _showSnackBar("Erreur: $e", isError: true);
    }
  }

  void _getLiveLocationUpdatesOfDriver() {
    positionStreamNewTripPage = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      driverCurrentPosition = position;
      driverPosition = LatLng(position.latitude, position.longitude);

      _updateDriverMarker();
      _updateTripDetailsInformation();
    });
  }

  void _updateDriverMarker() {
    if (driverPosition == null) return;

    markers.removeWhere((marker) {
      return marker.width == 50 && marker.height == 50;
    });

    markers.add(
      OSMMapService.createDriverMarker(driverPosition!),
    );

    if (_mapReady) {
      try {
        _mapController.move(driverPosition!, _mapController.camera.zoom);
      } catch (e) {
        print("⚠️ Impossible de centrer: $e");
      }
    }

    setState(() {});
  }

  Future<void> _updateTripDetailsInformation() async {
    if (directionRequested || driverPosition == null) return;

    directionRequested = true;

    LatLng destinationLatLng;

    if (statusOfTrip == "accepted") {
      destinationLatLng = widget.newTripDetailsInfo!.pickUpLatLng!;
    } else {
      destinationLatLng = widget.newTripDetailsInfo!.dropOffLatLng!;
    }

    try {
      final route = await OSRMRoutingService.getRoute(
        driverPosition!,
        destinationLatLng,
      );

      if (route != null) {
        setState(() {
          durationText = route.durationText;
          distanceText = route.distanceText;

          routePoints = route.geometry;
          polylines.clear();
          polylines.add(
            OSMMapService.createRoutePolyline(
              routePoints,
              color: AppColors.primary,
            ),
          );
        });
      }
    } catch (e) {
      print("❌ Erreur update route: $e");
    }

    directionRequested = false;
  }

  Future<void> _handleButtonAction() async {
    if (statusOfTrip == "accepted") {
      // ARRIVÉ
      setState(() {
        buttonTitleText = "DÉMARRER LA COURSE";
        buttonColor = AppColors.primary;
      });

      /// ✅ Supabase
      await SupabaseService.arriveTripLocation(
          widget.newTripDetailsInfo!.tripID!);

      setState(() {
        statusOfTrip = "arrived";
      });

      _showSnackBar("Vous êtes arrivé chez le client", isSuccess: true);
    } else if (statusOfTrip == "arrived") {
      // DÉMARRER LA COURSE
      setState(() {
        buttonTitleText = "TERMINER LA COURSE";
        buttonColor = AppColors.error;
      });

      /// ✅ Supabase
      await SupabaseService.startTrip(widget.newTripDetailsInfo!.tripID!);

      setState(() {
        statusOfTrip = "ontrip";
      });

      if (driverPosition != null) {
        await _obtainDirectionAndDrawRoute(
          driverPosition!,
          widget.newTripDetailsInfo!.dropOffLatLng!,
        );
      }

      _showSnackBar("Course démarrée", isSuccess: true);
    } else if (statusOfTrip == "ontrip") {
      // TERMINER LA COURSE
      await _endTripNow();
    }
  }

  Future<void> _endTripNow() async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) =>
      const LoadingDialog(messageText: 'Finalisation de la course...'),
    );

    // Calculer le tarif du trajet pickup → dropoff
    var directionDetailsEndTripInfo =
    await CommonMethods.getDirectionDetailsFromAPI(
      widget.newTripDetailsInfo!.pickUpLatLng!,
      widget.newTripDetailsInfo!.dropOffLatLng!,
    );

    if (!mounted) return;
    Navigator.pop(context);

    String fareAmount =
    (cMethods.calculateFareAmount(directionDetailsEndTripInfo!))
        .toString();

    print("💰 Tarif calculé: $fareAmount HTG");
    print("📍 De: ${widget.newTripDetailsInfo!.pickupAddress}");
    print("📍 À: ${widget.newTripDetailsInfo!.dropOffAddress}");

    /// ✅ Terminer la course dans Supabase
    final success = await SupabaseService.completeTrip(
      tripId: widget.newTripDetailsInfo!.tripID!,
      fareAmount: double.parse(fareAmount),
      distanceKm: directionDetailsEndTripInfo.distanceInKm,
      durationMinutes: directionDetailsEndTripInfo.durationInMinutes,
    );

    if (success) {
      positionStreamNewTripPage?.cancel();
      _displayPaymentDialog(fareAmount);
    } else {
      _showSnackBar("Erreur lors de la finalisation", isError: true);
    }
  }

  void _displayPaymentDialog(String fareAmount) {
    if (!mounted) return;
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) =>
          PaymentDialog(
            fareAmount: fareAmount,
            tripId: widget.newTripDetailsInfo!.tripID!,
            clientName: widget.newTripDetailsInfo!.userName ?? "Client",
          ),
    );
  }

  /// ✅ Sauvegarder les infos du chauffeur (Supabase)
  Future<void> _saveDriverDataToTripInfo() async {
    await SupabaseService.acceptTripRequest(
      tripId: widget.newTripDetailsInfo!.tripID!,
      driverName: driverName,
      driverPhone: driverPhone,
      driverPhoto: driverPhoto,
      carModel: carModel,
      carColor: carColor,
      carNumber: carNumber,
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showSnackBar("Impossible d'appeler", isError: true);
    }
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          tripId: widget.newTripDetailsInfo!.tripID!,
          clientName: widget.newTripDetailsInfo!.userName ?? "Client",
        ),
      ),
    );
  }

  Future<void> _navigateExternal() async {
    LatLng destination;
    if (statusOfTrip == "accepted") {
      destination = widget.newTripDetailsInfo!.pickUpLatLng!;
    } else {
      destination = widget.newTripDetailsInfo!.dropOffLatLng!;
    }

    final String googleMapsUrl =
        "google.navigation:q=${destination.latitude},${destination.longitude}&mode=d";
    final Uri uri = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar("Google Maps n'est pas installé.", isError: true);
    }
  }

  void _showSnackBar(String message,
      {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppColors.error
            : (isSuccess ? AppColors.success : AppColors.primary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Carte OSM
          FlutterMap(
            mapController: _mapController,
            options: OSMMapService.createMapOptions(
              center: driverPosition ??
                  widget.newTripDetailsInfo!.pickUpLatLng ??
                  haitiInitialPosition,
              zoom: 14.0,
            ),
            children: [
              OSMMapService.createTileLayer(),
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),

          // Card de progression en bas
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TripProgressCard(
              tripStatus: statusOfTrip,
              buttonText: buttonTitleText,
              buttonColor: buttonColor,
              durationText: durationText,
              distanceText: distanceText,
              userName: widget.newTripDetailsInfo!.userName ?? "Client",
              pickupAddress: widget.newTripDetailsInfo!.pickupAddress ?? "",
              dropoffAddress: widget.newTripDetailsInfo!.dropOffAddress ?? "",
              onCallPressed: () =>
                  _makePhoneCall(widget.newTripDetailsInfo!.userPhone ?? ""),
              onNavigatePressed: _navigateExternal,
              onChatPressed: _openChat,
              onActionPressed: _handleButtonAction,
            ),
          ),
        ],
      ),
    );
  }
}