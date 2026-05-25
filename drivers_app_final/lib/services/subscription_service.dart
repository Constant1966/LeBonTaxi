import 'package:drivers_app/models/subscription_plan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service complet de gestion des abonnements chauffeur
class SubscriptionService {
  static final _supabase = Supabase.instance.client;

  // ============================================================
  // PLANS DISPONIBLES
  // ============================================================

  /// Récupère les plans d'abonnement disponibles pour les chauffeurs
  static Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      final response = await _supabase
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .inFilter('target_audience', ['driver', 'both'])
          .order('price', ascending: true);

      final plans = (response as List)
          .map((e) => SubscriptionPlan.fromMap(e))
          .toList();

      print('✅ ${plans.length} plans d\'abonnement chauffeur chargés');
      return plans;
    } catch (e) {
      print('❌ Erreur getAvailablePlans: $e');
      // Fallback: essayer sans filtre target_audience si la colonne n'existe pas
      try {
        final response = await _supabase
            .from('subscription_plans')
            .select()
            .eq('is_active', true)
            .order('price', ascending: true);

        final plans = (response as List)
            .map((e) => SubscriptionPlan.fromMap(e))
            .toList();

        print('✅ ${plans.length} plans chargés (sans filtre audience)');
        return plans;
      } catch (e2) {
        print('❌ Erreur fallback getAvailablePlans: $e2');
        return [];
      }
    }
  }

  // ============================================================
  // ABONNEMENT ACTIF DU CHAUFFEUR
  // ============================================================

  /// Récupère l'abonnement actif du chauffeur
  static Future<DriverSubscription?> getActiveSubscription(String driverId) async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('subscription_history')
          .select('*, subscription_plans(*)')
          .eq('user_id', driverId)
          .eq('status', 'active')
          .gte('end_date', now)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) {
        print('ℹ️ Aucun abonnement actif pour le chauffeur $driverId');
        return null;
      }

      final subscription = DriverSubscription.fromMap(response);
      print('✅ Abonnement actif trouvé: ${subscription.planName} (expire: ${subscription.endDate})');
      return subscription;
    } catch (e) {
      print('❌ Erreur getActiveSubscription: $e');
      return null;
    }
  }

  /// Vérifie si le chauffeur a un abonnement actif
  static Future<bool> isSubscriptionActive(String driverId) async {
    final sub = await getActiveSubscription(driverId);
    return sub?.isActive ?? false;
  }

  /// Récupère le pourcentage de réduction actif
  static Future<double> getActiveDiscount(String driverId) async {
    final sub = await getActiveSubscription(driverId);
    if (sub != null && sub.isActive) {
      return sub.discountPercentage ?? 0.0;
    }
    return 0.0;
  }

  // ============================================================
  // SOUSCRIRE / ANNULER
  // ============================================================

  /// Souscrire à un plan d'abonnement
  static Future<bool> subscribeToPlan({
    required String driverId,
    required SubscriptionPlan plan,
  }) async {
    try {
      final now = DateTime.now();
      final endDate = now.add(Duration(days: plan.durationDays));

      // Vérifier s'il y a un abonnement actif
      final existing = await getActiveSubscription(driverId);
      if (existing != null && existing.isActive) {
        print('⚠️ Le chauffeur a déjà un abonnement actif');
        return false;
      }

      await _supabase.from('subscription_history').insert({
        'user_id': driverId,
        'plan_id': plan.id,
        'plan_name': plan.name,
        'plan_price': plan.price,
        'discount_percentage': plan.discountPercentage,
        'start_date': now.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': 'active',
      });

      print('✅ Abonnement souscrit: ${plan.name} jusqu\'au $endDate');
      return true;
    } catch (e) {
      print('❌ Erreur subscribeToPlan: $e');
      return false;
    }
  }

  /// Annuler un abonnement
  static Future<bool> cancelSubscription(String subscriptionId) async {
    try {
      await _supabase
          .from('subscription_history')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId);

      print('✅ Abonnement annulé: $subscriptionId');
      return true;
    } catch (e) {
      print('❌ Erreur cancelSubscription: $e');
      return false;
    }
  }

  // ============================================================
  // HISTORIQUE
  // ============================================================

  /// Récupère l'historique complet des abonnements
  static Future<List<DriverSubscription>> getSubscriptionHistory(String driverId) async {
    try {
      final response = await _supabase
          .from('subscription_history')
          .select('*, subscription_plans(*)')
          .eq('user_id', driverId)
          .order('created_at', ascending: false)
          .limit(50);

      final history = (response as List)
          .map((e) => DriverSubscription.fromMap(e))
          .toList();

      // Marquer les abonnements expirés
      for (var sub in history) {
        if (sub.status == 'active' && !sub.isActive) {
          // Auto-expirer côté local
          try {
            await _supabase
                .from('subscription_history')
                .update({'status': 'expired'})
                .eq('id', sub.id);
          } catch (_) {}
        }
      }

      print('✅ ${history.length} abonnements dans l\'historique');
      return history;
    } catch (e) {
      print('❌ Erreur getSubscriptionHistory: $e');
      return [];
    }
  }

  // ============================================================
  // VÉRIFICATION DE LA RÉDUCTION UTILISATEUR (pour le calcul de tarif)
  // ============================================================

  /// Récupère la réduction d'un UTILISATEUR (client) pour appliquer sur le tarif
  /// C'est cette méthode que le chauffeur utilise pour savoir si le client
  /// a une réduction
  static Future<double> getUserDiscount(String userId) async {
    try {
      final now = DateTime.now().toIso8601String();

      final response = await _supabase
          .from('subscription_history')
          .select('discount_percentage, subscription_plans(discount_percentage)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gte('end_date', now)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return 0.0;

      final discount = (response['discount_percentage'] as num?)?.toDouble() ??
          (response['subscription_plans']?['discount_percentage'] as num?)?.toDouble() ??
          0.0;

      print('💎 Réduction utilisateur: $discount%');
      return discount;
    } catch (e) {
      print('⚠️ Erreur getUserDiscount: $e');
      return 0.0;
    }
  }
}
