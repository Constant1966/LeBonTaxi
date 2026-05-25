import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de géocodage avec Nominatim (OpenStreetMap)
/// Avec cache, recherches récentes, destinations populaires
class GeocodingService {
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org';
  static DateTime _lastRequest = DateTime.now();

  // ✅ Cache pour les recherches
  static final Map<String, CacheEntry> _searchCache = {};


  // ✅ Cache pour le reverse geocoding
  static final Map<String, CacheEntry> _reverseCache = {};

  // ✅ Requête HTTP en cours (pour annulation)
  static http.Client? _activeClient;

  // ✅ Clé SharedPreferences
  static const String _recentSearchesKey = 'recent_searches_v2';
  static const int _maxRecentSearches = 10;

  /// 🔍 Recherche d'adresse avec cache + annulation
  static Future<List<Map<String, dynamic>>> searchAddress(String query) async {
    if (query.isEmpty) return [];

    // Vérifier le cache
    final cacheKey = query.toLowerCase().trim();
    if (_searchCache.containsKey(cacheKey)) {
      final entry = _searchCache[cacheKey]!;
      if (!entry.isExpired) {
        return List<Map<String, dynamic>>.from(entry.data);
      }
      _searchCache.remove(cacheKey);
    }

    // Annuler la requête précédente
    _activeClient?.close();
    _activeClient = http.Client();

    // Respecter la limite de 1 requête/seconde
    final now = DateTime.now();
    final diff = now.difference(_lastRequest).inMilliseconds;
    if (diff < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - diff));
    }

    final url = Uri.parse(
      '$_nominatimUrl/search'
      '?q=${Uri.encodeComponent(query)}'
      '&format=json'
      '&addressdetails=1'
      '&limit=10'
      '&countrycodes=ht',
    );

    try {
      _lastRequest = DateTime.now();

      final response = await _activeClient!.get(
        url,
        headers: {
          'User-Agent': 'LeBonTaxi/1.0 (contact@lebontaxi.com)',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final results = data.map((item) {
          // Déterminer la catégorie du lieu
          final String category = _getPlaceCategory(item);
          
          return {
            'place_id': item['place_id'].toString(),
            'name': item['display_name'],
            'main_text': item['display_name'].split(',').first,
            'secondary_text': item['display_name']
                .split(',')
                .skip(1)
                .join(',')
                .trim(),
            'lat': double.parse(item['lat']),
            'lng': double.parse(item['lon']),
            'category': category,
            'type': item['type'] ?? '',
            'class': item['class'] ?? '',
          };
        }).toList();

        // Mettre en cache
        _searchCache[cacheKey] = CacheEntry(results, DateTime.now());
        _cleanupCache();

        return results;
      }
    } catch (e) {
      if (e.toString().contains('ClientException')) {
        // Requête annulée - c'est normal
        return [];
      }
      print('❌ Erreur geocoding: $e');
    }

    return [];
  }

  /// 📍 Géocodage inverse avec cache
  static Future<String?> reverseGeocode(LatLng position) async {
    final cacheKey =
        '${position.latitude.toStringAsFixed(4)},${position.longitude.toStringAsFixed(4)}';

    if (_reverseCache.containsKey(cacheKey)) {
      final entry = _reverseCache[cacheKey]!;
      if (!entry.isExpired) {
        return entry.data as String?;
      }
      _reverseCache.remove(cacheKey);
    }

    final now = DateTime.now();
    final diff = now.difference(_lastRequest).inMilliseconds;
    if (diff < 1000) {
      await Future.delayed(Duration(milliseconds: 1000 - diff));
    }

    final url = Uri.parse(
      '$_nominatimUrl/reverse'
      '?lat=${position.latitude}'
      '&lon=${position.longitude}'
      '&format=json',
    );

    try {
      _lastRequest = DateTime.now();

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'LeBonTaxi/1.0 (contact@lebontaxi.com)',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['display_name'];

        _reverseCache[cacheKey] = CacheEntry(address, DateTime.now());

        return address;
      }
    } catch (e) {
      print('❌ Erreur reverse geocoding: $e');
    }

    return null;
  }

  // ═══════════════════════════════════════════
  // ✅ RECHERCHES RÉCENTES
  // ═══════════════════════════════════════════

  /// Sauvegarder une recherche récente
  static Future<void> saveRecentSearch(Map<String, dynamic> place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> recents =
          prefs.getStringList(_recentSearchesKey) ?? [];

      // Créer l'entrée
      final entry = jsonEncode({
        'main_text': place['main_text'],
        'secondary_text': place['secondary_text'],
        'lat': place['lat'],
        'lng': place['lng'],
        'name': place['name'],
        'category': place['category'] ?? 'place',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Supprimer duplicata
      recents.removeWhere((r) {
        try {
          final decoded = jsonDecode(r);
          return decoded['main_text'] == place['main_text'];
        } catch (_) {
          return false;
        }
      });

      // Ajouter en tête
      recents.insert(0, entry);

      // Limiter à _maxRecentSearches
      if (recents.length > _maxRecentSearches) {
        recents.removeRange(_maxRecentSearches, recents.length);
      }

      await prefs.setStringList(_recentSearchesKey, recents);
    } catch (e) {
      print('❌ Erreur sauvegarde recherche récente: $e');
    }
  }

  /// Charger les recherches récentes
  static Future<List<Map<String, dynamic>>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> recents =
          prefs.getStringList(_recentSearchesKey) ?? [];

      return recents.map((r) {
        try {
          return Map<String, dynamic>.from(jsonDecode(r));
        } catch (_) {
          return <String, dynamic>{};
        }
      }).where((m) => m.isNotEmpty).toList();
    } catch (e) {
      print('❌ Erreur chargement recherches récentes: $e');
      return [];
    }
  }

  /// Effacer les recherches récentes
  static Future<void> clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
    } catch (_) {}
  }

  // ═══════════════════════════════════════════
  // ✅ DESTINATIONS POPULAIRES (Haïti)
  // ═══════════════════════════════════════════

  /// Retourne les destinations populaires en Haïti
  static List<Map<String, dynamic>> getPopularDestinations() {
    return [
      {
        'main_text': 'Aéroport Toussaint Louverture',
        'secondary_text': 'Route de l\'Aéroport, Port-au-Prince',
        'lat': 18.5799,
        'lng': -72.2926,
        'name': 'Aéroport International Toussaint Louverture',
        'category': 'airport',
        'icon': '✈️',
      },
      {
        'main_text': 'Place Boyer',
        'secondary_text': 'Pétion-Ville, Port-au-Prince',
        'lat': 18.5107,
        'lng': -72.2873,
        'name': 'Place Boyer, Pétion-Ville',
        'category': 'landmark',
        'icon': '🏛️',
      },
      {
        'main_text': 'Marché de Fer',
        'secondary_text': 'Centre-ville, Port-au-Prince',
        'lat': 18.5432,
        'lng': -72.3388,
        'name': 'Marché de Fer, Port-au-Prince',
        'category': 'shopping',
        'icon': '🛒',
      },
      {
        'main_text': 'Hôpital Universitaire',
        'secondary_text': 'HUEH, Port-au-Prince',
        'lat': 18.5444,
        'lng': -72.3358,
        'name': 'Hôpital Universitaire d\'État d\'Haïti',
        'category': 'hospital',
        'icon': '🏥',
      },
      {
        'main_text': 'Champ de Mars',
        'secondary_text': 'Centre, Port-au-Prince',
        'lat': 18.5444,
        'lng': -72.3396,
        'name': 'Champ de Mars, Port-au-Prince',
        'category': 'landmark',
        'icon': '🏛️',
      },
      {
        'main_text': 'Université Quisqueya',
        'secondary_text': 'Haut Turgeau, Port-au-Prince',
        'lat': 18.5350,
        'lng': -72.3256,
        'name': 'Université Quisqueya',
        'category': 'education',
        'icon': '🎓',
      },
    ];
  }

  // ═══════════════════════════════════════════
  // ✅ UTILITAIRES
  // ═══════════════════════════════════════════

  /// Détermine la catégorie d'un lieu Nominatim
  static String _getPlaceCategory(Map<String, dynamic> item) {
    final String osmClass = item['class'] ?? '';
    final String osmType = item['type'] ?? '';

    if (osmClass == 'amenity') {
      if (['hospital', 'clinic', 'doctors', 'pharmacy'].contains(osmType)) {
        return 'hospital';
      }
      if (['restaurant', 'cafe', 'fast_food', 'bar'].contains(osmType)) {
        return 'restaurant';
      }
      if (['fuel', 'charging_station'].contains(osmType)) {
        return 'gas_station';
      }
      if (['school', 'university', 'college'].contains(osmType)) {
        return 'education';
      }
    }
    if (osmClass == 'tourism') {
      if (['hotel', 'motel', 'hostel', 'guest_house'].contains(osmType)) {
        return 'hotel';
      }
      return 'landmark';
    }
    if (osmClass == 'aeroway') return 'airport';
    if (osmClass == 'shop') return 'shopping';

    return 'place';
  }

  /// 🧹 Nettoie le cache expiré
  static void _cleanupCache() {
    if (_searchCache.length > 50) {
      _searchCache.removeWhere((key, entry) => entry.isExpired);
      _reverseCache.removeWhere((key, entry) => entry.isExpired);
    }
  }

  /// 🗑️ Vide le cache
  static void clearCache() {
    _searchCache.clear();
    _reverseCache.clear();
  }
}

/// Entrée de cache avec expiration
class CacheEntry {
  final dynamic data;
  final DateTime timestamp;

  CacheEntry(this.data, this.timestamp);

  bool get isExpired {
    return DateTime.now().difference(timestamp) > const Duration(minutes: 10);
  }
}