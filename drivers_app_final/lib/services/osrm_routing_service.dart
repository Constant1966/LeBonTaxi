import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service de calcul d'itinéraire avec OSRM (Open Source Routing Machine)
class OSRMRoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org';

  /// Calcule un itinéraire entre deux points
  static Future<OSRMRoute?> getRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/route/v1/driving/'
            '${start.longitude},${start.latitude};'
            '${end.longitude},${end.latitude}'
            '?overview=full'
            '&geometries=geojson'
            '&steps=true'
            '&annotations=true',
      );

      print('🛣️ OSRM route: ${start.latitude},${start.longitude} → ${end.latitude},${end.longitude}');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = OSRMRoute.fromJson(data['routes'][0]);
          print('✅ Route calculée: ${route.distanceText}, ${route.durationText}');
          return route;
        } else {
          print('❌ Pas de route trouvée');
          return null;
        }
      } else {
        print('❌ Erreur OSRM: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Exception OSRM: $e');
      return null;
    }
  }

  /// Calcule plusieurs itinéraires (pour comparaison)
  static Future<List<OSRMRoute>> getAlternativeRoutes(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/route/v1/driving/'
            '${start.longitude},${start.latitude};'
            '${end.longitude},${end.latitude}'
            '?overview=full'
            '&geometries=geojson'
            '&alternatives=3', // Demander 3 alternatives
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null) {
          return (data['routes'] as List)
              .map((routeJson) => OSRMRoute.fromJson(routeJson))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Exception alternatives OSRM: $e');
      return [];
    }
  }

  /// Décode une polyline encodée
  static List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}

/// Modèle pour un itinéraire OSRM
class OSRMRoute {
  final double distance; // en mètres
  final int duration; // en secondes
  final List<LatLng> geometry;
  final List<OSRMStep> steps;

  OSRMRoute({
    required this.distance,
    required this.duration,
    required this.geometry,
    required this.steps,
  });

  factory OSRMRoute.fromJson(Map<String, dynamic> json) {
    // Extraire la géométrie
    final geometryData = json['geometry'];
    List<LatLng> geometryPoints = [];

    if (geometryData is Map && geometryData['coordinates'] != null) {
      // GeoJSON format
      geometryPoints = (geometryData['coordinates'] as List)
          .map((coord) => LatLng(coord[1], coord[0]))
          .toList();
    }

    // Extraire les étapes
    List<OSRMStep> steps = [];
    if (json['legs'] != null) {
      for (var leg in json['legs']) {
        if (leg['steps'] != null) {
          steps.addAll(
            (leg['steps'] as List)
                .map((stepJson) => OSRMStep.fromJson(stepJson))
                .toList(),
          );
        }
      }
    }

    return OSRMRoute(
      distance: (json['distance'] ?? 0).toDouble(),
      duration: (json['duration'] ?? 0).toInt(),
      geometry: geometryPoints,
      steps: steps,
    );
  }

  /// Distance formatée (ex: "3.2 km")
  String get distanceText {
    if (distance < 1000) {
      return "${distance.round()} m";
    }
    return "${(distance / 1000).toStringAsFixed(1)} km";
  }

  /// Durée formatée (ex: "15 min")
  String get durationText {
    if (duration < 60) {
      return "$duration sec";
    }
    final minutes = (duration / 60).round();
    if (minutes < 60) {
      return "$minutes min";
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return "${hours}h ${remainingMinutes}min";
  }

  /// Distance en kilomètres
  double get distanceInKm => distance / 1000;

  /// Durée en minutes
  int get durationInMinutes => (duration / 60).round();
}

/// Modèle pour une étape d'itinéraire
class OSRMStep {
  final String instruction;
  final double distance;
  final int duration;
  final String? name;
  final LatLng? location;

  OSRMStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    this.name,
    this.location,
  });

  factory OSRMStep.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    if (json['maneuver'] != null && json['maneuver']['location'] != null) {
      final loc = json['maneuver']['location'];
      location = LatLng(loc[1], loc[0]);
    }

    return OSRMStep(
      instruction: json['maneuver']?['instruction'] ?? '',
      distance: (json['distance'] ?? 0).toDouble(),
      duration: (json['duration'] ?? 0).toInt(),
      name: json['name'],
      location: location,
    );
  }
}