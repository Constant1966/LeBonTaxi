import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Service pour récupérer les Points d'Intérêt via Overpass API (OpenStreetMap)
class POIService {
  static const String _overpassUrl =
      'https://overpass-api.de/api/interpreter';

  // Cache des POI
  static final Map<String, _POICacheEntry> _poiCache = {};


  /// Catégories disponibles
  static const Map<String, POICategory> categories = {
    'restaurant': POICategory(
      key: 'restaurant',
      label: 'Restaurants',
      icon: '🍽️',
      osmTag: '"amenity"~"restaurant|cafe|fast_food"',
    ),
    'hotel': POICategory(
      key: 'hotel',
      label: 'Hôtels',
      icon: '🏨',
      osmTag: '"tourism"~"hotel|motel|hostel|guest_house"',
    ),
    'gas_station': POICategory(
      key: 'gas_station',
      label: 'Stations',
      icon: '⛽',
      osmTag: '"amenity"="fuel"',
    ),
    'hospital': POICategory(
      key: 'hospital',
      label: 'Hôpitaux',
      icon: '🏥',
      osmTag: '"amenity"~"hospital|clinic|pharmacy"',
    ),
    'landmark': POICategory(
      key: 'landmark',
      label: 'Monuments',
      icon: '🏛️',
      osmTag: '"tourism"~"attraction|museum|monument"',
    ),
    'bank': POICategory(
      key: 'bank',
      label: 'Banques',
      icon: '🏦',
      osmTag: '"amenity"~"bank|atm"',
    ),
  };

  /// Rechercher les POI par catégorie
  static Future<List<POIResult>> searchNearby({
    required LatLng center,
    required String categoryKey,
    int radiusMeters = 3000,
    int limit = 20,
  }) async {
    final category = categories[categoryKey];
    if (category == null) return [];

    // Vérifier le cache
    final cacheKey =
        '${categoryKey}_${center.latitude.toStringAsFixed(3)}_${center.longitude.toStringAsFixed(3)}_$radiusMeters';
    if (_poiCache.containsKey(cacheKey)) {
      final entry = _poiCache[cacheKey]!;
      if (!entry.isExpired) {
        print('🔍 POI cache HIT: $categoryKey');
        return entry.results;
      }
      _poiCache.remove(cacheKey);
    }

    // Requête Overpass
    final query = '''
[out:json][timeout:10];
(
  node[${category.osmTag}](around:$radiusMeters,${center.latitude},${center.longitude});
  way[${category.osmTag}](around:$radiusMeters,${center.latitude},${center.longitude});
);
out center $limit;
''';

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
        headers: {
          'User-Agent': 'LeBonTaxi/1.0',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'] as List? ?? [];

        const Distance distCalc = Distance();
        final results = elements.map((e) {
          double lat, lng;

          if (e['type'] == 'way' && e['center'] != null) {
            lat = (e['center']['lat'] as num).toDouble();
            lng = (e['center']['lon'] as num).toDouble();
          } else {
            lat = (e['lat'] as num?)?.toDouble() ?? 0;
            lng = (e['lon'] as num?)?.toDouble() ?? 0;
          }

          final tags = e['tags'] as Map<String, dynamic>? ?? {};
          final distKm = distCalc.as(
            LengthUnit.Kilometer,
            center,
            LatLng(lat, lng),
          );

          return POIResult(
            id: e['id'].toString(),
            name: tags['name'] ?? tags['name:fr'] ?? category.label,
            category: categoryKey,
            categoryLabel: category.label,
            categoryIcon: category.icon,
            lat: lat,
            lng: lng,
            distanceKm: distKm,
            address: tags['addr:street'] ?? '',
            phone: tags['phone'] ?? tags['contact:phone'] ?? '',
            website: tags['website'] ?? tags['contact:website'] ?? '',
            openingHours: tags['opening_hours'] ?? '',
          );
        }).toList();

        // Trier par distance
        results.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

        // Mettre en cache
        _poiCache[cacheKey] = _POICacheEntry(results, DateTime.now());

        print('✅ ${results.length} POI trouvés pour $categoryKey');
        return results;
      }
    } catch (e) {
      print('❌ Erreur POI Overpass: $e');
    }

    return [];
  }

  /// Vider le cache POI
  static void clearCache() {
    _poiCache.clear();
  }
}

/// Catégorie de POI
class POICategory {
  final String key;
  final String label;
  final String icon;
  final String osmTag;

  const POICategory({
    required this.key,
    required this.label,
    required this.icon,
    required this.osmTag,
  });
}

/// Résultat POI
class POIResult {
  final String id;
  final String name;
  final String category;
  final String categoryLabel;
  final String categoryIcon;
  final double lat;
  final double lng;
  final double distanceKm;
  final String address;
  final String phone;
  final String website;
  final String openingHours;

  POIResult({
    required this.id,
    required this.name,
    required this.category,
    required this.categoryLabel,
    required this.categoryIcon,
    required this.lat,
    required this.lng,
    required this.distanceKm,
    this.address = '',
    this.phone = '',
    this.website = '',
    this.openingHours = '',
  });

  LatLng get position => LatLng(lat, lng);

  String get distanceText {
    if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }
}

/// Cache entry pour les POI
class _POICacheEntry {
  final List<POIResult> results;
  final DateTime timestamp;

  _POICacheEntry(this.results, this.timestamp);

  bool get isExpired =>
      DateTime.now().difference(timestamp) > const Duration(minutes: 30);
}
