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

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('id', userId!)
          .maybeSingle();

      if (response != null) {
        final profile = Map<String, dynamic>.from(response);
        // Injecter le fallback local si les champs d'urgence ou de parrainage ne sont pas présents ou sont nuls
        final prefs = await SharedPreferences.getInstance();
        if (profile['emergency_contact_name'] == null) {
          profile['emergency_contact_name'] = prefs.getString('local_emergency_contact_name_$userId');
        }
        if (profile['emergency_contact_phone'] == null) {
          profile['emergency_contact_phone'] = prefs.getString('local_emergency_contact_phone_$userId');
        }
        if (profile['referral_code'] == null) {
          profile['referral_code'] = prefs.getString('local_referral_code_$userId');
        }

        currentUserReferralCode = profile['referral_code']?.toString();
        currentUserReferredById = profile['referred_by_id']?.toString();

        return profile;
      }
      return null;
    } catch (e) {
      print("⚠️ Erreur getUserProfile Supabase: $e");
      // Fallback complet local en cas d'erreur de connexion
      final prefs = await SharedPreferences.getInstance();
      final localName = prefs.getString('last_user_name') ?? 'Utilisateur';
      final code = prefs.getString('local_referral_code_$userId');
      currentUserReferralCode = code;
      currentUserReferredById = prefs.getString('local_referred_by_id_$userId');
      return {
        'id': userId,
        'email': currentUser?.email ?? '',
        'name': localName,
        'phone': prefs.getString('last_user_phone') ?? '',
        'photo': prefs.getString('last_user_photo') ?? '',
        'emergency_contact_name': prefs.getString('local_emergency_contact_name_$userId'),
        'emergency_contact_phone': prefs.getString('local_emergency_contact_phone_$userId'),
        'referral_code': code,
        'referred_by_id': currentUserReferredById,
      };
    }
  }

  /// Mettre à jour le profil
  static Future<void> updateUserProfile(Map<String, dynamic> data) async {
    if (userId == null) return;

    // Sauvegarder localement d'abord en cache
    final prefs = await SharedPreferences.getInstance();
    if (data.containsKey('emergency_contact_name')) {
      await prefs.setString('local_emergency_contact_name_$userId', data['emergency_contact_name']?.toString() ?? '');
    }
    if (data.containsKey('emergency_contact_phone')) {
      await prefs.setString('local_emergency_contact_phone_$userId', data['emergency_contact_phone']?.toString() ?? '');
    }
    if (data.containsKey('referral_code')) {
      await prefs.setString('local_referral_code_$userId', data['referral_code']?.toString() ?? '');
      currentUserReferralCode = data['referral_code']?.toString();
    }
    if (data.containsKey('referred_by_id')) {
      await prefs.setString('local_referred_by_id_$userId', data['referred_by_id']?.toString() ?? '');
      currentUserReferredById = data['referred_by_id']?.toString();
    }
    if (data.containsKey('name')) {
      await prefs.setString('last_user_name', data['name']?.toString() ?? '');
    }
    if (data.containsKey('phone')) {
      await prefs.setString('last_user_phone', data['phone']?.toString() ?? '');
    }
    if (data.containsKey('photo')) {
      await prefs.setString('last_user_photo', data['photo']?.toString() ?? '');
    }

    try {
      await supabase
          .from('users')
          .update(data)
          .eq('id', userId!);
    } catch (e) {
      print("⚠️ Erreur lors de l'update Supabase, tentative de fallback sans les colonnes d'urgence et de parrainage: $e");
      // Si la mise à jour échoue (ex: colonnes inexistantes), on filtre les colonnes non prises en charge et on réessaye
      final filteredData = Map<String, dynamic>.from(data);
      filteredData.remove('emergency_contact_name');
      filteredData.remove('emergency_contact_phone');
      filteredData.remove('referral_code');
      filteredData.remove('referred_by_id');

      if (filteredData.isNotEmpty) {
        try {
          await supabase
              .from('users')
              .update(filteredData)
              .eq('id', userId!);
          print("✅ Profil mis à jour sur Supabase sans les nouvelles colonnes (sauvegardées localement)");
        } catch (e2) {
          print("❌ Échec de la mise à jour de secours sur Supabase: $e2");
          rethrow;
        }
      }
    }
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
  // PARRAINAGE & RÉCOMPENSES (REFERRAL SYSTEM)
  // ============================================

  /// Vérifier si un code de parrainage existe et récupérer le parrain
  static Future<Map<String, dynamic>?> checkReferralCode(String code) async {
    try {
      final response = await supabase
          .from('users')
          .select('id, name')
          .eq('referral_code', code.trim().toUpperCase())
          .maybeSingle();
      return response;
    } catch (e) {
      print("⚠️ Erreur checkReferralCode: $e");
      return null;
    }
  }

  /// Générer et sauvegarder un code de parrainage pour l'utilisateur connecté
  static Future<String> generateAndSaveReferralCode(String name) async {
    if (userId == null) return '';
    
    // Générer le code
    final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final namePart = cleanName.length >= 4 ? cleanName.substring(0, 4) : (cleanName + 'LBT').substring(0, 4);
    final randomNum = (1000 + (DateTime.now().microsecondsSinceEpoch % 9000)).toString();
    final generatedCode = 'LBT-$namePart$randomNum';

    currentUserReferralCode = generatedCode;

    // Cache local
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_referral_code_$userId', generatedCode);

    try {
      await supabase
          .from('users')
          .update({'referral_code': generatedCode})
          .eq('id', userId!);
      print("✅ Code de parrainage mis à jour sur Supabase: $generatedCode");
    } catch (e) {
      print("⚠️ Impossible d'enregistrer le code de parrainage sur Supabase (fallback local): $e");
    }

    return generatedCode;
  }

  /// Charger la récompense de parrainage active non utilisée
  static Future<void> loadActiveReferralReward() async {
    try {
      if (userId == null) return;

      // Charger aussi le message de partage et la config
      final settings = await supabase
          .from('app_settings')
          .select('referral_share_message')
          .eq('id', 1)
          .maybeSingle();
      if (settings != null && settings['referral_share_message'] != null) {
        globalReferralShareMessage = settings['referral_share_message'].toString();
      }

      final reward = await supabase
          .from('referral_rewards')
          .select()
          .eq('referrer_id', userId!)
          .eq('status', 'unused')
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (reward != null) {
        activeReferralRewardId = reward['id']?.toString();
        currentReferralDiscount = (reward['reward_value'] as num).toDouble();
        currentReferralDiscountType = reward['reward_type']?.toString();
        print("🎁 Récompense de parrainage active: ID=$activeReferralRewardId, Valeur=$currentReferralDiscount ($currentReferralDiscountType)");
      } else {
        activeReferralRewardId = null;
        currentReferralDiscount = 0.0;
        currentReferralDiscountType = null;
      }
    } catch (e) {
      print("⚠️ Erreur loadActiveReferralReward: $e");
      activeReferralRewardId = null;
      currentReferralDiscount = 0.0;
      currentReferralDiscountType = null;
    }
  }

  /// Marquer une récompense comme utilisée lors du trajet
  static Future<void> useReferralReward(String rewardId, String tripId) async {
    try {
      await supabase.from('referral_rewards').update({
        'status': 'used',
        'used_at': DateTime.now().toIso8601String(),
        'trip_id': tripId,
      }).eq('id', rewardId);
      
      print("✅ Récompense de parrainage $rewardId marquée comme utilisée pour la course $tripId");
      
      // Réinitialiser les globales de réduction après utilisation
      activeReferralRewardId = null;
      currentReferralDiscount = 0.0;
      currentReferralDiscountType = null;
    } catch (e) {
      print("❌ Erreur useReferralReward: $e");
    }
  }

  /// Déclencher la création d'une récompense pour le parrain (et éventuellement le filleul)
  static Future<void> triggerReferralReward(String referredId, String referrerId) async {
    try {
      // Charger les paramètres de parrainage depuis app_settings
      final settings = await supabase
          .from('app_settings')
          .select('referral_reward_enabled, referral_reward_type, referral_reward_value, referral_welcome_enabled, referral_welcome_type, referral_welcome_value')
          .eq('id', 1)
          .maybeSingle();

      if (settings != null) {
        final enabled = settings['referral_reward_enabled'] as bool? ?? true;
        if (!enabled) {
          print("ℹ️ Le programme de parrainage est désactivé par l'admin.");
          return;
        }

        final type = settings['referral_reward_type']?.toString() ?? 'percentage';
        final value = (settings['referral_reward_value'] as num?)?.toDouble() ?? 10.0;

        // 1. Récompense pour le parrain avec fallback résilient si la colonne is_welcome n'existe pas encore
        try {
          await supabase.from('referral_rewards').insert({
            'referrer_id': referrerId,
            'referred_id': referredId,
            'reward_type': type,
            'reward_value': value,
            'status': 'unused',
            'is_welcome': false,
          });
          print("🎁 Récompense de parrainage créée avec succès pour le parrain $referrerId");
        } catch (dbError) {
          print("⚠️ Échec d'insertion avec 'is_welcome', tentative de fallback sans cette colonne: $dbError");
          try {
            await supabase.from('referral_rewards').insert({
              'referrer_id': referrerId,
              'referred_id': referredId,
              'reward_type': type,
              'reward_value': value,
              'status': 'unused',
            });
            print("🎁 Récompense de parrainage créée pour le parrain $referrerId (fallback)");
          } catch (dbErrorFallback) {
            print("❌ Échec total de l'insertion parrain: $dbErrorFallback");
          }
        }

        // 2. Récompense de bienvenue pour le filleul (si configurée/activée)
        final welcomeEnabled = settings['referral_welcome_enabled'] as bool? ?? true;
        if (welcomeEnabled) {
          final welcomeType = settings['referral_welcome_type']?.toString() ?? 'percentage';
          final welcomeValue = (settings['referral_welcome_value'] as num?)?.toDouble() ?? 5.0;

          try {
            await supabase.from('referral_rewards').insert({
              'referrer_id': referredId, // Le filleul est le bénéficiaire de sa remise
              'referred_id': referrerId, // Le parrain est lié
              'reward_type': welcomeType,
              'reward_value': welcomeValue,
              'status': 'unused',
              'is_welcome': true,
            });
            print("🎁 Récompense de bienvenue créée avec succès pour le filleul $referredId");
          } catch (dbError2) {
            print("⚠️ Échec d'insertion de bienvenue avec 'is_welcome', fallback: $dbError2");
            try {
              await supabase.from('referral_rewards').insert({
                'referrer_id': referredId,
                'referred_id': referrerId,
                'reward_type': welcomeType,
                'reward_value': welcomeValue,
                'status': 'unused',
              });
              print("🎁 Récompense de bienvenue créée pour le filleul $referredId (fallback sans is_welcome)");
            } catch (dbError2Fallback) {
              print("❌ Échec total de l'insertion filleul: $dbError2Fallback");
            }
          }
        }

        // 3. Notification push pour le parrain (FCM Edge Function)
        try {
          final referrerUser = await supabase
              .from('users')
              .select('fcm_token')
              .eq('id', referrerId)
              .maybeSingle();

          final referredUser = await supabase
              .from('users')
              .select('name')
              .eq('id', referredId)
              .maybeSingle();

          if (referrerUser != null && referredUser != null) {
            final fcmToken = referrerUser['fcm_token']?.toString();
            final referredName = referredUser['name']?.toString() ?? 'Un ami';

            if (fcmToken != null && fcmToken.isNotEmpty) {
              final valStr = type == 'percentage' ? '$value%' : '$value HTG';
              await supabase.functions.invoke(
                'send-fcm-notification',
                body: {
                  'token': fcmToken,
                  'title': '🎁 Nouveau parrainage réussi !',
                  'body': '$referredName a rejoint LeBonTaxi grâce à vous. Vous gagnez -$valStr sur votre prochain trajet !',
                  'data': {
                    'type': 'referral_success',
                    'referred_name': referredName,
                  },
                },
              );
              print("🔔 Notification push de parrainage envoyée avec succès au parrain !");
            }
          }
        } catch (notifError) {
          print("⚠️ Échec lors de la notification push du parrain: $notifError");
        }
      }
    } catch (e) {
      print("❌ Erreur générale triggerReferralReward: $e");
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