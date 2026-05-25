import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/subscription_plan_model.dart';
import '../global/global_var_supabase.dart';

class SupabaseService {
  // Instance Supabase
  static final SupabaseClient supabase = Supabase.instance.client;

  // ============================================
  // AUTHENTIFICATION
  // ============================================

  /// Se connecter avec email et mot de passe
  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Créer un compte
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Se déconnecter
  static Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  // Méthode pour obtenir le profil complet
  static Future<Map<String, dynamic>?> getUserProfileComplete() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final profile = await supabase
          .from('users')
          .select('*')
          .eq('id', userId)
          .maybeSingle();

      return profile;
    } catch (e) {
      print("❌ Erreur getUserProfileComplete: $e");
      return null;
    }
  }

  /// Obtenir l'utilisateur actuel
  static User? get currentUser => supabase.auth.currentUser;

  /// Vérifier si connecté
  static bool get isAuthenticated => currentUser != null;

  /// UID de l'utilisateur
  static String? get userId => currentUser?.id;

  // ============================================
  // USERS (CLIENTS)
  // ============================================

  /// Créer un profil utilisateur
  static Future<void> createUserProfile({
    required String email,
    required String name,
    required String phone,
  }) async {
    await supabase.from('users').insert({
      'id': userId,
      'email': email,
      'name': name,
      'phone': phone,
      'block_status': 'no',
    });
  }

  /// Obtenir le profil utilisateur
  static Future<Map<String, dynamic>?> getUserProfile() async {
    if (userId == null) return null;

    final response = await supabase
        .from('users')
        .select()
        .eq('id', userId!)
        .maybeSingle();

    return response;
  }

  /// Mettre à jour le profil
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (userId == null) return;

    await supabase
        .from('users')
        .update(data)
        .eq('id', userId!);
  }

  // ============================================
  // DRIVERS (CHAUFFEURS)
  // ============================================

  /// Obtenir les chauffeurs en ligne à proximité
  static Future<List<Map<String, dynamic>>> getNearbyDrivers({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
  }) async {
    final response = await supabase.rpc(
      'nearby_drivers',
      params: {
        'user_lat': latitude,
        'user_lng': longitude,
        'radius_km': radiusKm,
      },
    );

    return List<Map<String, dynamic>>.from(response);
  }

  /// Écouter les chauffeurs en ligne (realtime)
  static Stream<List<Map<String, dynamic>>> watchOnlineDrivers() {
    return supabase
        .from('drivers')
        .stream(primaryKey: ['id'])
        .eq('is_online', true)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }

  // ============================================
  // TRIP REQUESTS (COURSES)
  // ============================================

  /// Créer une demande de course
  static Future<Map<String, dynamic>> createTripRequest({
    required String userName,
    required String userPhone,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required String distance,
    required String duration,
    required int fareAmount,
  }) async {
    final tripId = 'trip_${DateTime.now().millisecondsSinceEpoch}';

    final response = await supabase
        .from('trip_requests')
        .insert({
      'trip_id': tripId,
      'user_id': userId,
      'user_name': userName,
      'user_phone': userPhone,
      'status': 'new',
      'pickup_address': pickupAddress,
      'dropoff_address': dropoffAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'dropoff_lat': dropoffLat,
      'dropoff_lng': dropoffLng,
      'distance': distance,
      'duration': duration,
      'fare_amount': fareAmount,
    })
        .select()
        .single();

    return response;
  }

  /// Écouter les changements d'une course (realtime)
  static Stream<Map<String, dynamic>> watchTrip(String tripId) {
    return supabase
        .from('trip_requests')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .map((data) => data.first);
  }

  /// Mettre à jour le statut d'une course
  static Future<void> updateTripStatus({
    required String tripId,
    required String status,
  }) async {
    await supabase
        .from('trip_requests')
        .update({'status': status})
        .eq('trip_id', tripId);
  }

  /// Noter un chauffeur
  static Future<void> rateTrip({
    required String tripId,
    required int rating,
    String? comment,
  }) async {
    await supabase
        .from('trip_requests')
        .update({
      'rating': rating,
      'comment': comment,
      'rated_at': DateTime.now().toIso8601String(),
    })
        .eq('trip_id', tripId);

    // Mettre à jour la note moyenne du chauffeur
    // (sera fait par une fonction PostgreSQL ou trigger)
  }

  // ============================================
  // FAVORITES (LIEUX FAVORIS)
  // ============================================

  /// Obtenir les favoris
  static Future<List<Map<String, dynamic>>> getFavorites() async {
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('favorites')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print("Erreur favorites Supabase, fallback local: $e");
      final prefs = await SharedPreferences.getInstance();
      final favsString = prefs.getString('local_favorites_$userId');
      if (favsString != null) {
        final List<dynamic> decoded = jsonDecode(favsString);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
  }

  /// Ajouter un favori
  static Future<void> addFavorite({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    if (userId == null) return;

    final favoriteData = {
      'user_id': userId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };

    try {
      await supabase.from('favorites').insert(favoriteData);
    } catch (e) {
      print("Erreur ajout favori Supabase, save local: $e");
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> currentFavs = await getFavorites();
      favoriteData['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      currentFavs.insert(0, favoriteData);
      await prefs.setString('local_favorites_$userId', jsonEncode(currentFavs));
    }
  }

  /// Supprimer un favori
  static Future<void> deleteFavorite(String favoriteId) async {
    try {
      await supabase
          .from('favorites')
          .delete()
          .eq('id', favoriteId);
    } catch (e) {
      print("Erreur delete favori Supabase, fallback local: $e");
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> currentFavs = await getFavorites();
      currentFavs.removeWhere((element) => element['id'].toString() == favoriteId);
      await prefs.setString('local_favorites_$userId', jsonEncode(currentFavs));
    }
  }

  // ============================================
  // RECENT LOCATIONS (LIEUX RÉCENTS)
  // ============================================

  /// Obtenir les lieux récents
  static Future<List<Map<String, dynamic>>> getRecentLocations() async {
    if (userId == null) return [];

    final response = await supabase
        .from('recent_locations')
        .select()
        .eq('user_id', userId!)
        .order('visited_at', ascending: false)
        .limit(10);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Ajouter un lieu récent
  static Future<void> addRecentLocation({
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    if (userId == null) return;

    await supabase.from('recent_locations').insert({
      'user_id': userId,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  // ============================================
  // PAYMENT NOTIFICATIONS
  // ============================================

  /// Créer une notification de paiement pour le chauffeur
  static Future<void> createPaymentNotification({
    required String driverId,
    required String tripId,
    required String fareAmount,
    String? paymentMethod,
  }) async {
    await supabase.from('payment_notifications').insert({
      'driver_id': driverId,
      'trip_id': tripId,
      'fare_amount': fareAmount,
      'payment_method': paymentMethod,
    });
  }

  // ============================================
  // APP CONFIGURATION (TARIFICATION)
  // ============================================

  /// Récupérer la configuration globale des prix depuis Supabase
  static Future<void> fetchPricingConfig() async {
    try {
      final response = await supabase
          .from('app_settings')
          .select()
          .eq('id', 1)
          .maybeSingle();
          
      if (response != null) {
        if (response['base_fare'] != null) {
          globalBaseFare = (response['base_fare'] as num).toDouble();
        }
        if (response['per_km_rate'] != null) {
          globalPerKmRate = (response['per_km_rate'] as num).toDouble();
        }
        if (response['minimum_fare'] != null) {
          globalMinimumFare = (response['minimum_fare'] as num).toDouble();
        }
        print("✅ Tarification dynamique chargée: Base=$globalBaseFare, Km=$globalPerKmRate, Min=$globalMinimumFare");
      }
    } catch (e) {
      print("⚠️ Impossible de charger la configuration des prix (app_settings non trouvée ou erreur): $e");
    }
  }

  // ============================================
  // SUBSCRIPTION PLANS (ABONNEMENTS)
  // ============================================

  /// Récupérer les forfaits actifs provenant de Supabase (triés par display_order)
  static Future<List<SubscriptionPlan>> fetchSubscriptionPlans() async {
    try {
      final response = await supabase
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      return List<Map<String, dynamic>>.from(response)
          .map((data) => SubscriptionPlan.fromMap(data))
          .toList();
    } catch (e) {
      print("Erreur fetchSubscriptionPlans: $e");
      return [];
    }
  }

  /// Récupérer le pourcentage de réduction du plan d'un utilisateur
  static Future<double> getUserDiscountPercentage(String planId) async {
    try {
      final response = await supabase
          .from('subscription_plans')
          .select('discount_percentage')
          .eq('id', planId)
          .maybeSingle();
          
      if (response != null && response['discount_percentage'] != null) {
        return (response['discount_percentage'] as num).toDouble();
      }
    } catch (e) {
      print("Erreur getUserDiscountPercentage: $e");
    }
    return 0.0;
  }

  /// Charger le statut d'abonnement d'un utilisateur et mettre à jour les globales
  static Future<void> loadUserSubscriptionStatus() async {
    try {
      if (userId == null) return;

      final profile = await supabase
          .from('users')
          .select('subscription_plan_id, subscription_end_date')
          .eq('id', userId!)
          .maybeSingle();

      if (profile != null) {
        userSubscriptionPlanId = profile['subscription_plan_id']?.toString();
        if (profile['subscription_end_date'] != null) {
          userSubscriptionEndDate = DateTime.tryParse(
            profile['subscription_end_date'].toString(),
          );
        }

        // Récupérer la réduction si abonnement actif
        if (isUserSubscribed && userSubscriptionPlanId != null) {
          currentUserDiscount = await getUserDiscountPercentage(
            userSubscriptionPlanId!,
          );
          print("🚀 Abonnement actif : Réduction de $currentUserDiscount%");
        } else {
          currentUserDiscount = 0.0;
        }
      }
    } catch (e) {
      print("❌ Erreur loadUserSubscriptionStatus: $e");
      currentUserDiscount = 0.0;
    }
  }

  /// Créer un enregistrement d'abonnement dans l'historique
  static Future<void> createSubscriptionRecord({
    required String planId,
    required String planName,
    required double amountPaid,
    required DateTime startDate,
    required DateTime endDate,
    String paymentMethod = 'cash',
    String currency = 'HTG',
  }) async {
    if (userId == null) return;

    try {
      await supabase.from('subscription_history').insert({
        'user_id': userId,
        'plan_id': planId,
        'plan_name': planName,
        'amount_paid': amountPaid,
        'currency': currency,
        'payment_method': paymentMethod,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': 'active',
      });
      print("✅ Historique abonnement créé");
    } catch (e) {
      print("⚠️ Erreur création historique abonnement: $e");
    }
  }

  // ============================================
  // REALTIME — Messages Admin & Tarification (WebSocket)
  // ============================================

  /// Écouter les messages/annonces admin en temps réel
  /// Filtre: messages destinés à tous les utilisateurs OU à cet utilisateur
  static RealtimeChannel subscribeToAdminMessages({
    required Function(Map<String, dynamic>) onNewMessage,
  }) {
    return supabase.channel('admin_messages_user').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'admin_messages',
      callback: (payload) {
        final msg = payload.newRecord;
        final recipientType = msg['recipient_type']?.toString();
        final recipientId = msg['recipient_id']?.toString();

        // Recevoir si: destiné à tous les utilisateurs OU à cet utilisateur
        if (recipientType == 'all_users' ||
            (recipientType == 'single_user' && recipientId == userId)) {
          onNewMessage(msg);
        }
      },
    ).subscribe();
  }

  /// Écouter les changements de tarification en temps réel (WebSocket)
  /// Met à jour les variables globales de prix automatiquement
  static RealtimeChannel subscribeToAppSettings({
    required Function(Map<String, dynamic>) onSettingsChanged,
  }) {
    return supabase.channel('app_settings_user_realtime').onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'app_settings',
      callback: (payload) {
        final data = payload.newRecord;
        // Mettre à jour les variables globales de tarification
        if (data['base_fare'] != null) {
          globalBaseFare = (data['base_fare'] as num).toDouble();
        }
        if (data['per_km_rate'] != null) {
          globalPerKmRate = (data['per_km_rate'] as num).toDouble();
        }
        if (data['minimum_fare'] != null) {
          globalMinimumFare = (data['minimum_fare'] as num).toDouble();
        }
        print("💰 Tarification mise à jour via WebSocket: Base=$globalBaseFare, Km=$globalPerKmRate");
        onSettingsChanged(data);
      },
    ).subscribe();
  }
}