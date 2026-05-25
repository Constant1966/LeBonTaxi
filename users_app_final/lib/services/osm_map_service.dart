import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' show cos, sqrt, asin, sin, atan2;

/// Service pour gérer les cartes OpenStreetMap
class OSMMapService {

  /// Calcule la distance entre deux points en kilomètres
  static double calculateDistance(LatLng point1, LatLng point2) {
    const p = 0.017453292519943295; // Pi/180
    final a = 0.5 - cos((point2.latitude - point1.latitude) * p) / 2 +
        cos(point1.latitude * p) *
            cos(point2.latitude * p) *
            (1 - cos((point2.longitude - point1.longitude) * p)) /
            2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Crée un marqueur pour le chauffeur
  static Marker createDriverMarker(LatLng position, {double rotation = 0}) {
    return Marker(
      point: position,
      width: 40,
      height: 40,
      child: Transform.rotate(
        angle: rotation * (3.14159 / 180),
        child: Icon(
          Icons.navigation,
          color: Colors.blue,
          size: 40,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  /// Crée un marqueur pour le pickup (point de départ)
  static Marker createPickupMarker(LatLng position) {
    return Marker(
      point: position,
      width: 50,
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.person_pin_circle,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  /// Crée un marqueur pour le dropoff (destination)
  static Marker createDropoffMarker(LatLng position) {
    return Marker(
      point: position,
      width: 50,
      height: 50,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.flag,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  /// Crée une polyline pour afficher un itinéraire
  static Polyline createRoutePolyline(List<LatLng> points, {Color color = Colors.blue}) {
    return Polyline(
      points: points,
      strokeWidth: 5.0,
      color: color,
      borderStrokeWidth: 2.0,
      borderColor: Colors.white,
    );
  }

  /// Calcule les bounds pour afficher tous les points
  static LatLngBounds calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        const LatLng(18.5, -72.4),
        const LatLng(18.6, -72.2),
      );
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Ajouter un padding de 10%
    final latPadding = (maxLat - minLat) * 0.1;
    final lngPadding = (maxLng - minLng) * 0.1;

    return LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  /// Crée les options de la carte OSM
  static MapOptions createMapOptions({
    required LatLng center,
    double zoom = 13.0,
    double minZoom = 5.0,
    double maxZoom = 19.0,
    Function(LatLng)? onTap,
    Function(LatLng)? onLongPress,
    VoidCallback? onMapReady,
  }) {
    return MapOptions(
      initialCenter: center,
      initialZoom: zoom,
      minZoom: minZoom,
      maxZoom: maxZoom,
      onTap: onTap != null ? (_, point) => onTap(point) : null,
      onLongPress: onLongPress != null ? (_, point) => onLongPress(point) : null,
      onMapReady: onMapReady,
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all,
      ),
    );
  }


  /// Crée la couche de tuiles OSM
  static TileLayer createTileLayer() {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.lebontaxi.users',
      maxZoom: 19,
      maxNativeZoom: 19,
    );
  }

  /// Anime la caméra vers une position
  static void animateToPosition(
      MapController controller,
      LatLng position, {
        double zoom = 15.0,
      }) {
    controller.move(position, zoom);
  }

  /// Anime la caméra pour afficher plusieurs points
  static void animateToBounds(
      MapController controller,
      List<LatLng> points, {
        EdgeInsets padding = const EdgeInsets.all(50),
      }) {
    if (points.isEmpty) return;

    final bounds = calculateBounds(points);
    controller.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: padding,
      ),
    );
  }

  /// Calcule le bearing (direction) entre deux points
  static double calculateBearing(LatLng start, LatLng end) {
    const p = 0.017453292519943295; // Pi/180
    final lat1 = start.latitude * p;
    final lat2 = end.latitude * p;
    final dLng = (end.longitude - start.longitude) * p;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    return (atan2(y, x) * 180 / 3.14159 + 360) % 360;
  }

  /// Formatte la distance pour l'affichage
  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return "${(distanceInKm * 1000).round()} m";
    }
    return "${distanceInKm.toStringAsFixed(1)} km";
  }

  /// Formatte la durée pour l'affichage
  static String formatDuration(int durationInSeconds) {
    if (durationInSeconds < 60) {
      return "$durationInSeconds sec";
    }
    final minutes = (durationInSeconds / 60).round();
    if (minutes < 60) {
      return "$minutes min";
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return "${hours}h ${remainingMinutes}min";
  }
}