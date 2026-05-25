import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';


/// Service de calcul d'itinéraires avec OSRM (Open Source Routing Machine)
/// Avec retry, cache, instructions en français
class OSRMRoutingService {
  static const String _baseUrl = 'https://router.project-osrm.org';
  static const int _maxRetries = 3;

  // ✅ Cache des routes
  static final Map<String, _RouteCacheEntry> _routeCache = {};


  /// Calcule un itinéraire entre deux points (avec retry + cache)
  static Future<OSRMRoute?> getRoute(LatLng start, LatLng end) async {
    // ✅ Vérifier le cache
    final cacheKey = _getCacheKey(start, end);
    if (_routeCache.containsKey(cacheKey)) {
      final entry = _routeCache[cacheKey]!;
      if (!entry.isExpired) {
        print('🔍 Route cache HIT');
        return entry.route;
      }
      _routeCache.remove(cacheKey);
    }

    final url = Uri.parse(
      '$_baseUrl/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );

    // ✅ Retry avec backoff exponentiel
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final timeout = Duration(seconds: attempt == 1 ? 10 : 7);
        final response = await http.get(url).timeout(timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
            final route = OSRMRoute.fromJson(data['routes'][0]);

            // ✅ Mettre en cache
            _routeCache[cacheKey] = _RouteCacheEntry(route, DateTime.now());
            _cleanupRouteCache();

            print('✅ Route calculée (tentative $attempt): ${route.distanceText}, ${route.durationText}');
            return route;
          }
        }

        print('⚠️ OSRM tentative $attempt: status ${response.statusCode}');
      } catch (e) {
        print('⚠️ OSRM tentative $attempt échouée: $e');
      }

      // Backoff exponentiel avant retry (sauf dernière tentative)
      if (attempt < _maxRetries) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    // ✅ Fallback après tous les retries
    print('⚠️ Toutes les tentatives OSRM échouées → fallback ligne droite');
    return _getStraightLineFallback(start, end);
  }

  /// Génère un itinéraire de secours (ligne droite) si OSRM est K.O.
  static OSRMRoute _getStraightLineFallback(LatLng start, LatLng end) {
    const Distance distanceCalc = Distance();

    final double distMeters = distanceCalc.as(LengthUnit.Meter, start, end).toDouble();
    final double adjustedDist = distMeters * 1.4;
    final double durationSec = adjustedDist / 5.5;

    return OSRMRoute(
      distance: adjustedDist,
      duration: durationSec,
      geometry: [start, end],
      steps: [],
      isFallback: true,
    );
  }

  /// Calcule plusieurs itinéraires alternatifs
  static Future<List<OSRMRoute>> getAlternativeRoutes(
    LatLng start,
    LatLng end, {
    int alternatives = 2,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson&steps=true&alternatives=$alternatives',
    );

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['code'] == 'Ok' && data['routes'] != null) {
          return (data['routes'] as List)
              .map((route) => OSRMRoute.fromJson(route))
              .toList();
        }
      }
    } catch (e) {
      print('❌ Erreur alternatives OSRM: $e');
    }

    return [];
  }

  /// Estimation du trafic basée sur l'heure
  static TrafficEstimation getTrafficEstimation() {
    final now = DateTime.now();
    final hour = now.hour;
    final isWeekday = now.weekday <= 5;

    if (isWeekday) {
      // Heures de pointe Haiti: 7-9h et 16-19h
      if ((hour >= 7 && hour <= 9) || (hour >= 16 && hour <= 19)) {
        return TrafficEstimation.heavy;
      } else if ((hour >= 6 && hour < 7) || (hour >= 9 && hour <= 11) ||
          (hour >= 15 && hour < 16) || (hour >= 19 && hour <= 20)) {
        return TrafficEstimation.moderate;
      }
    }
    return TrafficEstimation.light;
  }

  /// Durée ajustée selon le trafic
  static double getTrafficAdjustedDuration(double baseDuration) {
    final traffic = getTrafficEstimation();
    switch (traffic) {
      case TrafficEstimation.heavy:
        return baseDuration * 1.4;
      case TrafficEstimation.moderate:
        return baseDuration * 1.2;
      case TrafficEstimation.light:
        return baseDuration;
    }
  }

  static String _getCacheKey(LatLng start, LatLng end) {
    return '${start.latitude.toStringAsFixed(5)},${start.longitude.toStringAsFixed(5)}'
        '->${end.latitude.toStringAsFixed(5)},${end.longitude.toStringAsFixed(5)}';
  }

  static void _cleanupRouteCache() {
    if (_routeCache.length > 20) {
      _routeCache.removeWhere((_, entry) => entry.isExpired);
    }
  }

  /// Vider le cache
  static void clearCache() {
    _routeCache.clear();
  }
}

/// Estimation du trafic
enum TrafficEstimation { light, moderate, heavy }

extension TrafficEstimationExt on TrafficEstimation {
  String get label {
    switch (this) {
      case TrafficEstimation.light:
        return 'Fluide';
      case TrafficEstimation.moderate:
        return 'Modéré';
      case TrafficEstimation.heavy:
        return 'Dense';
    }
  }

  String get emoji {
    switch (this) {
      case TrafficEstimation.light:
        return '🟢';
      case TrafficEstimation.moderate:
        return '🟡';
      case TrafficEstimation.heavy:
        return '🔴';
    }
  }

  double get multiplier {
    switch (this) {
      case TrafficEstimation.light:
        return 1.0;
      case TrafficEstimation.moderate:
        return 1.2;
      case TrafficEstimation.heavy:
        return 1.4;
    }
  }
}

/// Cache entry pour les routes
class _RouteCacheEntry {
  final OSRMRoute route;
  final DateTime timestamp;

  _RouteCacheEntry(this.route, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 15);
}

/// Modèle pour une route OSRM
class OSRMRoute {
  final double distance; // en mètres
  final double duration; // en secondes
  final List<LatLng> geometry; // Points de la route
  final List<OSRMStep> steps; // Étapes de navigation
  final bool isFallback; // true si c'est un itinéraire de secours

  OSRMRoute({
    required this.distance,
    required this.duration,
    required this.geometry,
    required this.steps,
    this.isFallback = false,
  });

  /// Distance en kilomètres
  double get distanceInKm => distance / 1000;

  /// Durée en minutes
  double get durationInMinutes => duration / 60;

  /// Distance formatée (ex: "3.2 km")
  String get distanceText {
    if (distanceInKm < 1) {
      return "${distance.round()} m";
    }
    return "${distanceInKm.toStringAsFixed(1)} km";
  }

  /// Durée formatée (ex: "15 min")
  String get durationText {
    if (duration < 60) {
      return "${duration.round()} sec";
    }
    final minutes = durationInMinutes.round();
    if (minutes < 60) {
      return "$minutes min";
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return "${hours}h ${remainingMinutes}min";
  }

  /// Durée ajustée au trafic formatée
  String get trafficAdjustedDurationText {
    final adjusted = OSRMRoutingService.getTrafficAdjustedDuration(duration);
    if (adjusted < 60) {
      return "${adjusted.round()} sec";
    }
    final minutes = (adjusted / 60).round();
    if (minutes < 60) {
      return "$minutes min";
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return "${hours}h ${remainingMinutes}min";
  }

  /// Crée une route depuis JSON OSRM
  factory OSRMRoute.fromJson(Map<String, dynamic> json) {
    // Extraire la géométrie
    List<LatLng> geometry = [];
    if (json['geometry'] != null && json['geometry']['coordinates'] != null) {
      final coords = json['geometry']['coordinates'] as List;
      geometry = coords.map((coord) {
        return LatLng(
          (coord[1] as num).toDouble(),
          (coord[0] as num).toDouble(),
        );
      }).toList();
    }

    // Extraire les étapes
    List<OSRMStep> steps = [];
    if (json['legs'] != null && json['legs'].isNotEmpty) {
      final leg = json['legs'][0];
      if (leg['steps'] != null) {
        steps = (leg['steps'] as List)
            .map((step) => OSRMStep.fromJson(step))
            .toList();
      }
    }

    return OSRMRoute(
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      geometry: geometry,
      steps: steps,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'duration': duration,
      'distanceText': distanceText,
      'durationText': durationText,
      'geometry': geometry.map((p) => [p.longitude, p.latitude]).toList(),
    };
  }
}

/// Modèle pour une étape de navigation
class OSRMStep {
  final double distance;
  final double duration;
  final String name;
  final String maneuverType;
  final String maneuverModifier;
  final LatLng? maneuverLocation;

  OSRMStep({
    required this.distance,
    required this.duration,
    required this.name,
    required this.maneuverType,
    required this.maneuverModifier,
    this.maneuverLocation,
  });

  factory OSRMStep.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    if (json['maneuver'] != null && json['maneuver']['location'] != null) {
      final loc = json['maneuver']['location'] as List;
      if (loc.length >= 2) {
        location = LatLng(
          (loc[1] as num).toDouble(),
          (loc[0] as num).toDouble(),
        );
      }
    }

    return OSRMStep(
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      name: json['name']?.toString() ?? '',
      maneuverType: json['maneuver']?['type']?.toString() ?? '',
      maneuverModifier: json['maneuver']?['modifier']?.toString() ?? '',
      maneuverLocation: location,
    );
  }

  /// Instruction en français
  String get instructionText {
    final streetName = name.isNotEmpty ? ' sur $name' : '';

    switch (maneuverType) {
      case 'depart':
        return 'Départ$streetName';
      case 'arrive':
        return 'Arrivée à destination';
      case 'turn':
        return '${_getDirectionText()}$streetName';
      case 'new name':
        return 'Continuez$streetName';
      case 'merge':
        return 'Entrez sur$streetName';
      case 'fork':
        return maneuverModifier.contains('left')
            ? 'Prenez la fourche à gauche$streetName'
            : 'Prenez la fourche à droite$streetName';
      case 'roundabout':
        return 'Au rond-point$streetName';
      case 'end of road':
        return '${_getDirectionText()}$streetName';
      case 'continue':
        return 'Continuez tout droit$streetName';
      default:
        return 'Continuez$streetName';
    }
  }

  String _getDirectionText() {
    switch (maneuverModifier) {
      case 'left':
        return 'Tournez à gauche';
      case 'right':
        return 'Tournez à droite';
      case 'slight left':
        return 'Tournez légèrement à gauche';
      case 'slight right':
        return 'Tournez légèrement à droite';
      case 'sharp left':
        return 'Tournez fortement à gauche';
      case 'sharp right':
        return 'Tournez fortement à droite';
      case 'straight':
        return 'Continuez tout droit';
      case 'uturn':
        return 'Faites demi-tour';
      default:
        return 'Continuez';
    }
  }

  /// Icône correspondant à la direction
  String get directionIcon {
    switch (maneuverModifier) {
      case 'left':
      case 'slight left':
      case 'sharp left':
        return '↰';
      case 'right':
      case 'slight right':
      case 'sharp right':
        return '↱';
      case 'uturn':
        return '↩';
      case 'straight':
        return '↑';
      default:
        if (maneuverType == 'depart') return '📍';
        if (maneuverType == 'arrive') return '🏁';
        return '↑';
    }
  }

  String get distanceText {
    if (distance < 1000) {
      return "${distance.round()} m";
    }
    return "${(distance / 1000).toStringAsFixed(1)} km";
  }

  String get durationText {
    if (duration < 60) {
      return "${duration.round()} sec";
    }
    return "${(duration / 60).round()} min";
  }
}