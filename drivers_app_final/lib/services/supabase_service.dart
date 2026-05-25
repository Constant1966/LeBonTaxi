import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ✅ Service Supabase FINAL - TOUTES ERREURS CORRIGÉES
/// Compatible Supabase Dart v2.x
class SupabaseService {
  static final supabase = Supabase.instance.client;

  // ============================================================
  // AUTHENTICATION
  // ============================================================

  static Future<AuthResponse> signInWithGoogle({
    required String idToken,
    required String accessToken,
  }) async {
    return await supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  static User? getCurrentUser() {
    return supabase.auth.currentUser;
  }

  static Session? getCurrentSession() {
    return supabase.auth.currentSession;
  }

  // ============================================================
  // DRIVER PROFILE
  // ============================================================

  static Future<Map<String, dynamic>?> getDriverProfile(String driverId) async {
    try {
      final response = await supabase
          .from('drivers')
          .select()
          .eq('id', driverId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Erreur getDriverProfile: $e');
      return null;
    }
  }

  static Future<bool> createDriverProfile({
    required String email,
    required String name,
    String? photo,
  }) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) {
        print('❌ User ID null dans createDriverProfile');
        return false;
      }

      print('📝 Création profil pour: $email (ID: $userId)');

      // Insérer avec .select() pour vérifier le résultat
      final response = await supabase.from('drivers').insert({
        'id': userId,
        'email': email,
        'name': name,
        'photo': photo,
        'verified': false,
        'profile_completed': false,
        'block_status': 'no',
        'is_available': false,
        'is_online': false,
      }).select();

      if (response.isEmpty) {
        print('❌ Insertion retournée vide');
        return false;
      }

      print('✅ Profil créé avec succès: $response');
      return true;
    } catch (e) {
      print('❌ Erreur createDriverProfile: $e');

      // Si l'erreur est "duplicate key" c'est OK, le profil existe déjà
      if (e.toString().contains('duplicate') || e.toString().contains('23505')) {
        print('ℹ️ Profil existe déjà');
        return true;
      }

      return false;
    }
  }

  static Future<bool> ensureDriverProfileExists() async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) return false;

      // Vérifier si existe
      final existing = await getDriverProfile(userId);
      if (existing != null) {
        print('✅ Profil existe déjà');
        return true;
      }

      // Récupérer les infos du user
      final user = getCurrentUser();
      if (user == null) return false;

      // Créer le profil
      return await createDriverProfile(
        email: user.email ?? '',
        name: user.userMetadata?['name'] ?? user.email ?? 'Chauffeur',
        photo: user.userMetadata?['picture'],
      );
    } catch (e) {
      print('❌ Erreur ensureDriverProfileExists: $e');
      return false;
    }
  }



  static Future<bool> updateDriverProfile(Map<String, dynamic> data) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase.from('drivers').update(data).eq('id', userId);

      print('✅ Profil chauffeur mis à jour');
      return true;
    } catch (e) {
      print('❌ Erreur updateDriverProfile: $e');
      return false;
    }
  }

  static Future<bool> completeDriverProfile({
    required String phone,
    required String carModel,
    required String carColor,
    required String carNumber,
    required String carYear,
    String? photo,
    String? carFrontPhoto,
    String? carBackPhoto,
    String? carSidePhoto,
    String? licensePhoto,
    String? nin,
  }) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase.from('drivers').update({
        'phone': phone,
        'photo': photo,
        'car_model': carModel,
        'car_color': carColor,
        'car_number': carNumber,
        'car_year': carYear,
        'car_front_photo': carFrontPhoto,
        'car_back_photo': carBackPhoto,
        'car_side_photo': carSidePhoto,
        'license_photo': licensePhoto,
        'nin': nin,
        'profile_completed': true,
      }).eq('id', userId);

      print('✅ Profil chauffeur complété');
      return true;
    } catch (e) {
      print('❌ Erreur completeDriverProfile: $e');
      return false;
    }
  }

  // ============================================================
  // STORAGE (Photos)
  // ============================================================

  static Future<String?> uploadPhoto(String filePath, String folder) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      final file = File(filePath);
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = '$folder/$fileName';

      await supabase.storage.from('driver_photos').upload(storagePath, file);

      final publicUrl =
      supabase.storage.from('driver_photos').getPublicUrl(storagePath);

      print('✅ Photo uploadée: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Erreur uploadPhoto: $e');
      return null;
    }
  }

  // ============================================================
  // LOCATION
  // ============================================================

  static Future<bool> updateDriverLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase.from('drivers').update({
        'current_latitude': latitude,
        'current_longitude': longitude,
        'last_location_update': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      return true;
    } catch (e) {
      print('❌ Erreur updateDriverLocation: $e');
      return false;
    }
  }

  static Future<bool> toggleAvailability(bool isOnline) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase.from('drivers').update({
        'is_online': isOnline,
        'is_available': isOnline,
      }).eq('id', userId);

      print('✅ Disponibilité: ${isOnline ? "EN LIGNE" : "HORS LIGNE"}');
      return true;
    } catch (e) {
      print('❌ Erreur toggleAvailability: $e');
      return false;
    }
  }

  static Future<bool> saveFCMToken(String token) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      await supabase.from('drivers').update({
        'fcm_token': token,
      }).eq('id', userId);

      print('✅ FCM Token sauvegardé');
      return true;
    } catch (e) {
      print('❌ Erreur saveFCMToken: $e');
      return false;
    }
  }

  // ============================================================
  // TRIP REQUESTS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getAvailableTrips() async {
    try {
      final response = await supabase
          .from('trip_requests')
          .select()
          .eq('status', 'new')
          .order('created_at', ascending: false)
          .limit(20);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('❌ Erreur getAvailableTrips: $e');
      return [];
    }
  }

  static Future<bool> acceptTripRequest({
    required String tripId,
    required String driverName,
    required String driverPhone,
    required String? driverPhoto,
    required String carModel,
    required String carColor,
    required String carNumber,
  }) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Vérifier que la course est toujours disponible
      final trip = await supabase
          .from('trip_requests')
          .select()
          .eq('trip_id', tripId)
          .eq('status', 'new')
          .maybeSingle();

      if (trip == null) {
        print('⚠️ Course déjà acceptée ou non trouvée');
        return false;
      }

      // Accepter la course
      await supabase.from('trip_requests').update({
        'status': 'accepted',
        'driver_id': userId,
        'driver_name': driverName,
        'driver_phone': driverPhone,
        'driver_photo': driverPhoto,
        'car_model': carModel,
        'car_color': carColor,
        'car_number': carNumber,
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('trip_id', tripId).eq('status', 'new');

      print('✅ Course acceptée: $tripId');

      // ✅ FIX: Marquer le chauffeur comme non-disponible pendant la course
      await supabase.from('drivers').update({
        'is_available': false,
      }).eq('id', userId);

      return true;
    } catch (e) {
      print('❌ Erreur acceptTripRequest: $e');
      return false;
    }
  }

  static Future<bool> arriveTripLocation(String tripId) async {
    try {
      await supabase.from('trip_requests').update({
        'status': 'arrived',
        'arrived_at': DateTime.now().toIso8601String(),
      }).eq('trip_id', tripId);

      print('✅ Statut mis à jour: ARRIVÉ');
      return true;
    } catch (e) {
      print('❌ Erreur arriveTripLocation: $e');
      return false;
    }
  }

  static Future<bool> startTrip(String tripId) async {
    try {
      await supabase.from('trip_requests').update({
        'status': 'ontrip',
        'started_at': DateTime.now().toIso8601String(),
      }).eq('trip_id', tripId);

      print('✅ Course démarrée');
      return true;
    } catch (e) {
      print('❌ Erreur startTrip: $e');
      return false;
    }
  }

  static Future<bool> completeTrip({
    required String tripId,
    required double fareAmount,
    required double distanceKm,
    required int durationMinutes,
  }) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Mettre à jour la course
      await supabase.from('trip_requests').update({
        'status': 'completed',
        'fare_amount': fareAmount,
        'distance_km': distanceKm,
        'duration_minutes': durationMinutes,
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('trip_id', tripId);

      // ✅ FIX: Remettre le chauffeur comme disponible après la course
      await supabase.from('drivers').update({
        'is_available': true,
      }).eq('id', userId);

      try {
        // Essayer les deux variantes de l'RPC ou un insert direct
        await supabase.rpc('record_earning', params: {
          'p_driver_id': userId,
          'p_trip_id': tripId,
          'p_amount': fareAmount,
          'p_tip': 0.0, // Pour éviter l'erreur d'overloading
        });
      } catch (rpcError) {
        print('⚠️ Avertissement RPC record_earning: $rpcError');
        // Fallback: insertion directe
        try {
          await supabase.from('earnings').insert({
            'driver_id': userId,
            'trip_id': tripId,
            'amount': fareAmount,
          });
        } catch (insertError) {
          print('⚠️ Avertissement insert earnings: $insertError');
        }
      }

      print('✅ Course terminée');
      return true;
    } catch (e) {
      print('❌ Erreur completeTrip: $e');
      return false;
    }
  }

  static Future<bool> cancelTrip(String tripId, String reason) async {
    try {
      await supabase.from('trip_requests').update({
        'status': 'cancelled',
        'cancel_reason': reason,
        'cancelled_at': DateTime.now().toIso8601String(),
      }).eq('trip_id', tripId);

      print('✅ Course annulée');
      return true;
    } catch (e) {
      print('❌ Erreur cancelTrip: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getTripDetails(String tripId) async {
    try {
      final response = await supabase
          .from('trip_requests')
          .select()
          .eq('trip_id', tripId)
          .maybeSingle();

      return response;
    } catch (e) {
      print('❌ Erreur getTripDetails: $e');
      return null;
    }
  }

  // ============================================================
  // HISTORY & STATISTICS
  // ============================================================

  static Future<List<Map<String, dynamic>>> getDriverTripsHistory({
    String? status,
    int limit = 50,
  }) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) return [];

      // ✅ Construire la requête avec tous les filtres AVANT .order() et .limit()
      var query = supabase
          .from('trip_requests')
          .select()
          .eq('driver_id', userId);

      // Ajouter le filtre status si fourni
      if (status != null) {
        query = query.eq('status', status);
      }

      // Appliquer order et limit à la fin
      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('❌ Erreur getDriverTripsHistory: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> getDriverStatistics() async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) {
        return {
        'rating': 0.0, 'total_ratings': 0, 'total_trips': 0,
        'completed_trips': 0, 'total_earnings': 0.0,
        'today_trips': 0, 'today_earnings': 0.0,
        'week_trips': 0, 'week_earnings': 0.0,
        'month_trips': 0, 'month_earnings': 0.0,
      };
      }

      // Récupérer les gains totaux
      final earnings = await supabase
          .from('earnings')
          .select()
          .eq('driver_id', userId);

      final earningsList = earnings as List;
      double totalEarnings = 0;
      for (var earning in earningsList) {
        totalEarnings += (earning['amount'] as num?)?.toDouble() ?? 0;
      }

      // Récupérer les ratings
      final ratings = await supabase
          .from('ratings')
          .select()
          .eq('driver_id', userId);

      final ratingsList = ratings as List;
      double totalRatings = 0;
      for (var rating in ratingsList) {
        totalRatings += (rating['rating'] as num?)?.toDouble() ?? 0;
      }

      double averageRating =
      ratingsList.isNotEmpty ? totalRatings / ratingsList.length : 0;

      // Compter les courses terminées
      final completedTrips = await supabase
          .from('trip_requests')
          .select()
          .eq('driver_id', userId)
          .eq('status', 'completed');

      final completedList = completedTrips as List;

      // Stats aujourd'hui
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final todayTrips = await supabase
          .from('trip_requests')
          .select()
          .eq('driver_id', userId)
          .eq('status', 'completed')
          .gte('created_at', startOfDay.toIso8601String());

      final todayTripsList = todayTrips as List;
      double todayEarnings = 0;
      for (var trip in todayTripsList) {
        todayEarnings += (trip['fare_amount'] as num?)?.toDouble() ?? 0;
      }

      // Stats cette semaine
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final weekTrips = await supabase
          .from('trip_requests')
          .select()
          .eq('driver_id', userId)
          .eq('status', 'completed')
          .gte('created_at', weekStart.toIso8601String());

      final weekTripsList = weekTrips as List;
      double weekEarnings = 0;
      for (var trip in weekTripsList) {
        weekEarnings += (trip['fare_amount'] as num?)?.toDouble() ?? 0;
      }

      // Stats ce mois
      final monthStart = DateTime(today.year, today.month, 1);

      final monthTrips = await supabase
          .from('trip_requests')
          .select()
          .eq('driver_id', userId)
          .eq('status', 'completed')
          .gte('created_at', monthStart.toIso8601String());

      final monthTripsList = monthTrips as List;
      double monthEarnings = 0;
      for (var trip in monthTripsList) {
        monthEarnings += (trip['fare_amount'] as num?)?.toDouble() ?? 0;
      }

      return {
        'rating': averageRating,
        'total_ratings': ratingsList.length,
        'total_trips': completedList.length,
        'completed_trips': completedList.length,
        'total_earnings': totalEarnings,
        'today_trips': todayTripsList.length,
        'today_earnings': todayEarnings,
        'week_trips': weekTripsList.length,
        'week_earnings': weekEarnings,
        'month_trips': monthTripsList.length,
        'month_earnings': monthEarnings,
      };
    } catch (e) {
      print('❌ Erreur getDriverStatistics: $e');
      return {
        'rating': 0.0,
        'total_ratings': 0,
        'total_trips': 0,
        'completed_trips': 0,
        'total_earnings': 0.0,
        'today_trips': 0,
        'today_earnings': 0.0,
        'week_trips': 0,
        'week_earnings': 0.0,
        'month_trips': 0,
        'month_earnings': 0.0,
      };
    }
  }

  static Future<List<Map<String, dynamic>>> getDailyEarnings({int days = 30}) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) return [];

      final startDate = DateTime.now().subtract(Duration(days: days));

      final response = await supabase
          .from('earnings')
          .select()
          .eq('driver_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('❌ Erreur getDailyEarnings: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getDriverRatings() async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) return [];

      final response = await supabase
          .from('ratings')
          .select()
          .eq('driver_id', userId)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('❌ Erreur getDriverRatings: $e');
      return [];
    }
  }

  // ============================================================
  // EMERGENCY / URGENCE 🚨
  // ============================================================

  /// Récupérer l'historique des derniers paiements
  static Future<List<Map<String, dynamic>>> getPaymentHistory({int limit = 10}) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      final data = await supabase
          .from('trip_requests')
          .select()
          .eq('driver_id', userId)
          .eq('status', 'completed')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('❌ Erreur getPaymentHistory: $e');
      return [];
    }
  }

  /// Accepter une urgence (atomique — premier arrivé, premier servi)
  static Future<bool> acceptEmergency({
    required String emergencyId,
    required String driverName,
    required String driverPhone,
  }) async {
    try {
      final userId = getCurrentUser()?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Vérifier que l'urgence est toujours disponible
      final emergency = await supabase
          .from('emergency_requests')
          .select()
          .eq('id', emergencyId)
          .eq('status', 'new')
          .maybeSingle();

      if (emergency == null) {
        print('⚠️ Urgence déjà prise en charge ou inexistante');
        return false;
      }

      // Accepter l'urgence
      await supabase.from('emergency_requests').update({
        'status': 'accepted',
        'driver_id': userId,
        'driver_name': driverName,
        'driver_phone': driverPhone,
        'accepted_at': DateTime.now().toIso8601String(),
      }).eq('id', emergencyId).eq('status', 'new');

      print('✅ Urgence acceptée: $emergencyId');
      return true;
    } catch (e) {
      print('❌ Erreur acceptEmergency: $e');
      return false;
    }
  }

  /// Marquer une urgence comme résolue
  static Future<bool> resolveEmergency(String emergencyId) async {
    try {
      await supabase.from('emergency_requests').update({
        'status': 'resolved',
        'resolved_at': DateTime.now().toIso8601String(),
      }).eq('id', emergencyId);

      print('✅ Urgence résolue: $emergencyId');
      return true;
    } catch (e) {
      print('❌ Erreur resolveEmergency: $e');
      return false;
    }
  }

  /// Souscrire aux urgences en temps réel
  static RealtimeChannel subscribeToEmergencies({
    required Function(Map<String, dynamic>) onNewEmergency,
  }) {
    return supabase.channel('public:emergency_requests').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'emergency_requests',
      callback: (payload) {
        final newEmergency = payload.newRecord;
        if (newEmergency['status'] == 'new') {
          onNewEmergency(newEmergency);
        }
      },
    ).subscribe();
  }

  // ============================================================
  // REALTIME (Subscriptions)
  // ============================================================

  static RealtimeChannel subscribeToAvailableTrips({
    required Function(Map<String, dynamic>) onNewTrip,
  }) {
    return supabase.channel('public:trip_requests').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'trip_requests',
      callback: (payload) {
        final newTrip = payload.newRecord;
        if (newTrip['status'] == 'new') {
          onNewTrip(newTrip);
        }
      },
    ).subscribe();
  }

  static RealtimeChannel subscribeToTrip({
    required String tripId,
    required Function(Map<String, dynamic>) onUpdate,
  }) {
    return supabase.channel('trip_$tripId').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'trip_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'trip_id',
        value: tripId,
      ),
      callback: (payload) {
        onUpdate(payload.newRecord);
      },
    ).subscribe();
  }

  /// Écouter les annulations de courses acceptées par ce chauffeur
  static RealtimeChannel subscribeToTripCancellation({
    required String driverId,
    required Function(Map<String, dynamic>) onTripCancelled,
  }) {
    return supabase.channel('trip_cancellations_$driverId').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'trip_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'driver_id',
        value: driverId,
      ),
      callback: (payload) {
        final data = payload.newRecord;
        if (data['status'] == 'cancelled') {
          onTripCancelled(data);
        }
      },
    ).subscribe();
  }

  /// Mettre à jour le token FCM (lors d'un renouvellement)
  static Future<bool> updateFCMToken(String newToken) async {
    return saveFCMToken(newToken);
  }

  // ============================================================
  // REALTIME — Messages Admin & Tarification
  // ============================================================

  /// Écouter les messages/annonces admin en temps réel (WebSocket)
  /// Filtre: messages destinés à tous les chauffeurs OU à ce chauffeur spécifiquement
  static RealtimeChannel subscribeToAdminMessages({
    required Function(Map<String, dynamic>) onNewMessage,
  }) {
    return supabase.channel('admin_messages_driver').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'admin_messages',
      callback: (payload) {
        final msg = payload.newRecord;
        final recipientType = msg['recipient_type']?.toString();
        final recipientId = msg['recipient_id']?.toString();
        final userId = getCurrentUser()?.id;

        // Recevoir si: destiné à tous les chauffeurs OU à ce chauffeur
        if (recipientType == 'all_drivers' ||
            (recipientType == 'single_driver' && recipientId == userId)) {
          onNewMessage(msg);
        }
      },
    ).subscribe();
  }

  /// Écouter les changements de tarification en temps réel (WebSocket)
  /// Quand l'admin modifie les prix, le chauffeur reçoit la mise à jour instantanément
  static RealtimeChannel subscribeToAppSettings({
    required Function(Map<String, dynamic>) onSettingsChanged,
  }) {
    return supabase.channel('app_settings_realtime').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'app_settings',
      callback: (payload) {
        onSettingsChanged(payload.newRecord);
      },
    ).subscribe();
  }
}