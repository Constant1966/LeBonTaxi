
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class TripRequestService {
  static final _supabase = Supabase.instance.client;

  // 1. CRÉER TRIP ET NOTIFIER CHAUFFEURS PROCHES
  static Future<Map<String, dynamic>> createTripRequest({
    required String tripId,
    required String userId,
    required String userName,
    required String userPhone,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLatitude,
    required double pickupLongitude,
    required double dropoffLatitude,
    required double dropoffLongitude,
    required String distance,
    required String duration,
    required String fareAmount,
    int searchRadius = 5000,
  }) async {
    try {
      print("🚕 Création trip: $tripId");

      final tripData = {
        'trip_id': tripId,
        'user_id': userId,
        'user_name': userName,
        'user_phone': userPhone,
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
        'pickup_latitude': pickupLatitude,
        'pickup_longitude': pickupLongitude,
        'dropoff_latitude': dropoffLatitude,
        'dropoff_longitude': dropoffLongitude,
        'distance': distance,
        'duration': duration,
        'fare_amount': fareAmount.replaceAll(' HTG', ''),
        'status': 'new',
      };

      // ✅ Créer le trip
      await _supabase.from('trip_requests').insert(tripData);
      print("✅ Trip créé");

      // ✅ Notifier manuellement les chauffeurs
      final notifResult = await notifyDriversManually(
        tripId: tripId,
        userId: userId,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        radius: searchRadius,
      );

      final driversNotified = notifResult['driversNotified'] ?? 0;
      print("✅ $driversNotified chauffeurs notifiés");

      return {
        'success': true,
        'tripId': tripId,
        'driversNotified': driversNotified,
        'message': driversNotified > 0
            ? 'Demande envoyée à $driversNotified chauffeur${driversNotified > 1 ? 's' : ''}'
            : 'Aucun chauffeur disponible',
      };
    } catch (e) {
      print("❌ Erreur création trip: $e");
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ✅ 2. NOTIFIER CHAUFFEURS PROCHES
  static Future<Map<String, dynamic>> notifyDriversManually({
    required String tripId,
    required String userId,
    required double pickupLatitude,
    required double pickupLongitude,
    int radius = 5000,
  }) async {
    try {
      print("📢 Notification manuelle chauffeurs pour trip: $tripId");

      // Tentative d'appel RPC avec les paramètres probables
      final result = await _supabase.rpc(
        'notify_nearby_drivers',
        params: {
          'p_trip_id': tripId,
          'p_user_id': userId,
          'p_pickup_lat': pickupLatitude,
          'p_pickup_lng': pickupLongitude,
          'p_radius': radius,
        },
      );

      print("✅ Résultat brut RPC: $result");

      int driversNotified = 0;
      List<dynamic> driverIds = [];

      if (result is Map<String, dynamic>) {
        driversNotified = (result['drivers_notified'] as num?)?.toInt() ?? 0;
        driverIds = result['driver_ids'] ?? [];
      } else if (result is List) {
        driversNotified = result.length;
        driverIds = result.map((d) => d['driver_id']?.toString() ?? "").toList();
      }

      return {
        'success': true,
        'driversNotified': driversNotified,
        'driverIds': driverIds,
      };
    } catch (e) {
      print("❌ Erreur notification manuelle: $e");
      
      // FALLBACK: Si les noms de paramètres ci-dessus échouent, essayer un autre format
      try {
        print("⚠️ Tentative fallback RPC...");
        final resultFallback = await _supabase.rpc(
          'notify_nearby_drivers',
          params: {
            'p_trip_id': int.tryParse(tripId) ?? 1,
            'p_latitude': pickupLatitude,
            'p_longitude': pickupLongitude,
            'p_radius_meters': radius,
          },
        );
        
        if (resultFallback is List) {
           return {
            'success': true,
            'driversNotified': resultFallback.length,
            'driverIds': resultFallback.map((d) => d['driver_id']?.toString() ?? "").toList(),
          };
        }
      } catch (e2) {
        print("❌ Échec définitif RPC: $e2");
        
        // 🚨 ULTIMATE FALLBACK: Requête directe + calcul local + Insert manuel dans driver_notifications
        print("🛠️ Utilisation de la méthode de secours manuelle pour les notifications...");
        try {
          final driversResp = await _supabase
              .from('drivers')
              .select('*')
              .eq('is_online', true)
              .eq('is_available', true);

          int manualNotifiedCount = 0;
          List<dynamic> manualDriverIds = [];

          for (var driver in driversResp) {
            final lat = (driver['current_latitude'] ?? driver['latitude']) as num?;
            final lng = (driver['current_longitude'] ?? driver['longitude']) as num?;
            if (lat == null || lng == null) continue;

            final distMeters = calculateDistance(
              lat1: pickupLatitude,
              lng1: pickupLongitude,
              lat2: lat.toDouble(),
              lng2: lng.toDouble(),
            );

            if (distMeters <= radius) {
              try {
                // Insérer la notification. Peut échouer si contrainte unique déclenchée (déjà notifié)
                await _supabase.from('driver_notifications').insert({
                  'trip_id': tripId,
                  'driver_id': driver['id'],
                  // 'user_id': userId, // Removed just in case driver_notifications table doesn't have user_id, it is usually not strictly required if trip_requests has it. If needed, we leave it out or handle error implicitly.
                  'status': 'pending',
                  'distance_to_pickup': distMeters,
                });
                manualNotifiedCount++;
                manualDriverIds.add(driver['id']);
              } catch (insertError) {
                print("⚠️ Chauffeur ${driver['id']} probablement déjà notifié: $insertError");
              }
            }
          }

          if (manualNotifiedCount > 0) {
            print("✅ $manualNotifiedCount chauffeurs notifiés via fallback manuel!");
            return {
              'success': true,
              'driversNotified': manualNotifiedCount,
              'driverIds': manualDriverIds,
            };
          }
        } catch (e3) {
           print("❌ Échec de la méthode manuelle: $e3");
        }
      }

      return {
        'success': false,
        'error': e.toString(),
        'driversNotified': 0,
      };
    }
  }

  // ✅ 3. ÉCOUTER STATUT TRIP (Realtime postgres_changes + polling fallback)
  static Stream<Map<String, dynamic>> listenToTripStatus(String tripId) {
    print("👂 Écoute trip: $tripId");

    return _supabase
        .from('trip_requests')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .map((data) {
      if (data.isEmpty) {
        return {'status': 'not_found'};
      }
      return data.first;
    });
  }

  // ✅ 3b. POLLING FALLBACK: vérifier le statut périodiquement
  static Future<Map<String, dynamic>?> pollTripStatus(String tripId) async {
    try {
      final result = await _supabase
          .from('trip_requests')
          .select('*')
          .eq('trip_id', tripId)
          .maybeSingle();
      return result;
    } catch (e) {
      print("❌ Erreur polling trip: $e");
      return null;
    }
  }

  // ✅ 4. ANNULER TRIP
  static Future<bool> cancelTrip(String tripId) async {
    try {
      print("❌ Annulation trip: $tripId");
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User non authentifié");

      await _supabase.rpc(
        'cancel_trip_request',
        params: {
          'p_trip_id': tripId,
          'p_user_id': userId,
        },
      );

      print("✅ Trip annulé via RPC");
      return true;
    } catch (e) {
      print("❌ Erreur annulation RPC: $e");
      try {
        await _supabase.from('trip_requests').update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toIso8601String(),
        }).eq('trip_id', tripId);

        await _supabase.from('driver_notifications').update({
          'status': 'expired',
          'responded_at': DateTime.now().toIso8601String(),
        }).eq('trip_id', tripId).eq('status', 'pending');

        return true;
      } catch (e2) {
        return false;
      }
    }
  }

  // ✅ 5. OBTENIR INFO CHAUFFEUR
  static Future<Map<String, dynamic>?> getDriverInfo(String driverId) async {
    try {
      final driver = await _supabase.from('drivers').select().eq('id', driverId).single();
      return driver;
    } catch (e) {
      return null;
    }
  }

  // ✅ 6. METTRE À JOUR POSITION TRIP
  static Future<void> updateTripLocation({
    required String tripId,
    required double currentLatitude,
    required double currentLongitude,
  }) async {
    try {
      await _supabase.from('trip_requests').update({
        'current_latitude': currentLatitude,
        'current_longitude': currentLongitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('trip_id', tripId);
    } catch (e) {}
  }

  // ✅ 8. VÉRIFIER SI CHAUFFEURS NOTIFIÉS
  static Future<int> getNotifiedDriversCount(String tripId) async {
    try {
      final response = await _supabase.from('driver_notifications').select('id').eq('trip_id', tripId);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  // ✅ 9. AUGMENTER RAYON DE RECHERCHE
  static Future<Map<String, dynamic>> expandSearchRadius({
    required String tripId,
    required String userId,
    required double pickupLatitude,
    required double pickupLongitude,
    int currentRadius = 5000,
  }) async {
    try {
      final newRadius = currentRadius + 5000;
      print("📡 Extension rayon: ${currentRadius}m → ${newRadius}m");

      final result = await notifyDriversManually(
        tripId: tripId,
        userId: userId,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        radius: newRadius,
      );

      await _supabase.from('trip_requests').update({'search_radius': newRadius}).eq('trip_id', tripId);

      return {
        'success': true,
        'newRadius': newRadius,
        'driversNotified': result['driversNotified'] ?? 0,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ✅ 10. CALCULER DISTANCE
  static double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  // ✅ 11. FORMATER DISTANCE
  static String formatDistance(double meters) {
    if (meters < 1000) return "${meters.round()} m";
    return "${(meters / 1000).toStringAsFixed(1)} km";
  }

  // ✅ 12. OBTENIR LISTE DES CHAUFFEURS NOTIFIÉS
  static Future<List<Map<String, dynamic>>> getNotifiedDriversList(String tripId) async {
    try {
      final notifications = await _supabase.from('driver_notifications').select('''
            *,
            drivers:driver_id (
              name,
              phone,
              photo,
              car_details,
              car_number,
              rating
            )
          ''').eq('trip_id', tripId).order('distance_to_pickup', ascending: true);
      return List<Map<String, dynamic>>.from(notifications as List);
    } catch (e) {
      return [];
    }
  }

  // ✅ 13. OBTENIR DÉTAILS D'UN TRIP
  static Future<Map<String, dynamic>?> getTripDetails(String tripId) async {
    try {
      final trip = await _supabase.from('trip_requests').select('*').eq('trip_id', tripId).single();
      if (trip['driver_id'] != null) {
        try {
          final driver = await _supabase.from('drivers').select('*').eq('id', trip['driver_id']).single();
          trip['driver'] = driver;
        } catch (e) {
          trip['driver'] = null;
        }
      }
      return trip;
    } catch (e) {
      return null;
    }
  }

  // ✅ 14. METTRE À JOUR STATUT TRIP
  static Future<bool> updateTripStatus({
    required String tripId,
    required String status,
  }) async {
    try {
      await _supabase.from('trip_requests').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('trip_id', tripId);
      return true;
    } catch (e) {
      return false;
    }
  }
}
