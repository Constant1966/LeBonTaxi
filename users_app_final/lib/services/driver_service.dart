import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service pour gérer les chauffeurs dans l'app USERS
class DriverService {
  static final _supabase = Supabase.instance.client;

  /// Obtenir les chauffeurs proches
  /// Essaie d'abord la RPC, puis fallback sur une requête directe
  static Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required LatLng userLocation,
    int radiusMeters = 5000,
    int limit = 20,
  }) async {
    // ✅ ESSAI 1 : RPC (si la fonction existe)
    try {
      final response = await _supabase.rpc(
        'get_nearby_drivers',
        params: {
          'p_latitude': userLocation.latitude,
          'p_longitude': userLocation.longitude,
          'p_radius_meters': radiusMeters,
          'p_limit': limit,
        },
      );

      if (response != null && (response as List).isNotEmpty) {
        return response
            .map((driver) => driver as Map<String, dynamic>)
            .toList();
      }
    } catch (e) {
      print('⚠️ RPC get_nearby_drivers indisponible, fallback requête directe: $e');
    }

    // ✅ ESSAI 2 : Requête directe sur la table drivers
    return _getDriversDirect(userLocation, radiusMeters, limit);
  }

  /// Fallback : requête directe sur la table drivers
  static Future<List<Map<String, dynamic>>> _getDriversDirect(
    LatLng userLocation,
    int radiusMeters,
    int limit,
  ) async {
    try {
      // Récupérer les chauffeurs en ligne et disponibles
      final response = await _supabase
          .from('drivers')
          .select()
          .eq('is_online', true)
          .eq('is_available', true)
          .limit(limit);

      if (response.isEmpty) return [];

      final radiusKm = radiusMeters / 1000;
      const Distance distance = Distance();

      // Filtrer par distance côté client
      final nearbyDrivers = <Map<String, dynamic>>[];

      for (var driver in response) {
        // Supporter les deux conventions de colonnes
        final lat = (driver['current_latitude'] ?? driver['latitude']) as num?;
        final lng = (driver['current_longitude'] ?? driver['longitude']) as num?;

        if (lat == null || lng == null) continue;

        final driverPos = LatLng(lat.toDouble(), lng.toDouble());
        final dist = distance.as(
          LengthUnit.Kilometer,
          userLocation,
          driverPos,
        );

        if (dist <= radiusKm) {
          // Ajouter la distance calculée
          driver['distance_km'] = dist;
          // S'assurer que current_latitude/longitude sont remplis
          driver['current_latitude'] ??= driver['latitude'];
          driver['current_longitude'] ??= driver['longitude'];
          nearbyDrivers.add(driver);
        }
      }

      // Trier par distance
      nearbyDrivers.sort((a, b) =>
          (a['distance_km'] as num).compareTo(b['distance_km'] as num));

      print('✅ ${nearbyDrivers.length} chauffeurs trouvés dans un rayon de ${radiusKm}km');
      return nearbyDrivers;
    } catch (e) {
      print('❌ Erreur récupération chauffeurs (direct): $e');
      return [];
    }
  }

  /// Obtenir un chauffeur spécifique par ID
  static Future<Map<String, dynamic>?> getDriver(String driverId) async {
    try {
      final response = await _supabase
          .from('drivers')
          .select('*')
          .eq('id', driverId)
          .single();

      return response;
    } catch (e) {
      print('❌ Erreur récupération chauffeur $driverId: $e');
      return null;
    }
  }

  /// Écouter la position d'un chauffeur en temps réel
  static Stream<Map<String, dynamic>?> listenToDriverLocation(String driverId) {
    return _supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .map((data) {
      if (data.isEmpty) return null;
      return data.first;
    });
  }

  /// Vérifier si un chauffeur est en ligne et disponible
  static Future<bool> isDriverAvailable(String driverId) async {
    try {
      final driver = await _supabase
          .from('drivers')
          .select('is_online, is_available')
          .eq('id', driverId)
          .single();

      return driver['is_online'] == true &&
          driver['is_available'] == true;
    } catch (e) {
      print('❌ Erreur vérification disponibilité: $e');
      return false;
    }
  }
}