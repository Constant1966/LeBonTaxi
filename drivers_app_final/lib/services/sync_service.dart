import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drivers_app/services/local_database_service.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/global/global_var.dart';

/// Service de synchronisation offline ↔ online
class SyncService {
  static bool _isSyncing = false;

  // ============================================================
  // VÉRIFICATION CONNECTIVITÉ
  // ============================================================

  static Future<bool> isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  // ============================================================
  // SYNCHRONISATION COMPLÈTE
  // ============================================================

  /// Synchroniser toutes les données (appelé au retour en ligne)
  static Future<void> syncAll() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final online = await isOnline();
      if (!online) {
        print('📴 Pas de connexion, synchronisation reportée');
        return;
      }

      print('🔄 Début synchronisation complète...');

      // 1. Traiter les actions en attente
      await _processPendingActions();

      // 2. Synchroniser le profil
      await syncDriverProfile();

      // 3. Synchroniser les courses
      await syncTripsHistory();

      // 4. Synchroniser les gains
      await syncEarnings();

      print('✅ Synchronisation complète terminée');
    } catch (e) {
      print('❌ Erreur synchronisation: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ============================================================
  // TRAITEMENT DES ACTIONS EN ATTENTE
  // ============================================================

  static Future<void> _processPendingActions() async {
    try {
      final pendingActions = await LocalDatabaseService.getPendingActions();

      if (pendingActions.isEmpty) {
        print('✅ Aucune action en attente');
        return;
      }

      print('📋 ${pendingActions.length} actions en attente à traiter');

      for (var action in pendingActions) {
        try {
          final actionType = action['action_type'] as String;
          final payload = jsonDecode(action['payload'] as String) as Map<String, dynamic>;

          bool success = false;

          switch (actionType) {
            case 'update_location':
              success = await SupabaseService.updateDriverLocation(
                latitude: payload['latitude'],
                longitude: payload['longitude'],
              );
              break;

            case 'toggle_availability':
              success = await SupabaseService.toggleAvailability(
                payload['is_online'] as bool,
              );
              break;

            case 'update_profile':
              success = await SupabaseService.updateDriverProfile(payload);
              break;

            default:
              print('⚠️ Type d\'action inconnu: $actionType');
              success = true; // Marquer comme traité pour ne pas bloquer
          }

          if (success) {
            await LocalDatabaseService.markActionCompleted(action['id'] as int);
            print('✅ Action traitée: $actionType');
          }
        } catch (e) {
          print('❌ Erreur traitement action ${action['id']}: $e');
        }
      }

      // Nettoyer les actions complétées
      await LocalDatabaseService.clearCompletedActions();
    } catch (e) {
      print('❌ Erreur _processPendingActions: $e');
    }
  }

  // ============================================================
  // SYNCHRONISATION PROFIL
  // ============================================================

  static Future<void> syncDriverProfile() async {
    try {
      final user = SupabaseService.getCurrentUser();
      if (user == null) return;

      final profile = await SupabaseService.getDriverProfile(user.id);
      if (profile != null) {
        // Sauvegarder en local
        await LocalDatabaseService.saveDriverProfile(profile);

        // Mettre à jour les variables globales
        _updateGlobalVars(profile);

        print('✅ Profil synchronisé (Supabase → Local)');
      }
    } catch (e) {
      print('❌ Erreur syncDriverProfile: $e');
    }
  }

  /// Charger le profil depuis le cache local (mode hors-ligne)
  static Future<Map<String, dynamic>?> loadProfileFromCache() async {
    try {
      final profile = await LocalDatabaseService.getAnyDriverProfile();
      if (profile != null) {
        _updateGlobalVars(profile);
        print('📱 Profil chargé depuis le cache local');
      }
      return profile;
    } catch (e) {
      print('❌ Erreur loadProfileFromCache: $e');
      return null;
    }
  }

  static void _updateGlobalVars(Map<String, dynamic> profile) {
    driverId = profile['id'] ?? '';
    driverName = profile['name'] ?? '';
    driverPhone = profile['phone'] ?? '';
    driverPhoto = profile['photo'] ?? '';
    driverEmail = profile['email'] ?? '';
    carModel = profile['car_model'] ?? '';
    carColor = profile['car_color'] ?? '';
    carNumber = profile['car_number'] ?? '';
    carYear = profile['car_year'] ?? '';
    carFrontPhoto = profile['car_front_photo'] ?? '';
    carBackPhoto = profile['car_back_photo'] ?? '';
    carSidePhoto = profile['car_side_photo'] ?? '';
    fcmToken = profile['fcm_token'] ?? '';
  }

  // ============================================================
  // SYNCHRONISATION COURSES
  // ============================================================

  static Future<void> syncTripsHistory() async {
    try {
      final trips = await SupabaseService.getDriverTripsHistory(limit: 100);
      if (trips.isNotEmpty) {
        await LocalDatabaseService.saveTrips(trips);
        print('✅ ${trips.length} courses synchronisées');
      }
    } catch (e) {
      print('❌ Erreur syncTripsHistory: $e');
    }
  }

  // ============================================================
  // SYNCHRONISATION GAINS
  // ============================================================

  static Future<void> syncEarnings() async {
    try {
      final earnings = await SupabaseService.getDailyEarnings(days: 90);
      if (earnings.isNotEmpty) {
        await LocalDatabaseService.saveEarnings(earnings);
        print('✅ ${earnings.length} gains synchronisés');
      }
    } catch (e) {
      print('❌ Erreur syncEarnings: $e');
    }
  }

  // ============================================================
  // ÉCOUTER LES CHANGEMENTS DE CONNECTIVITÉ
  // ============================================================

  static void startListeningConnectivity() {
    Connectivity().onConnectivityChanged.listen((results) {
      final isConnected = !results.contains(ConnectivityResult.none);
      if (isConnected) {
        print('🌐 Connexion rétablie, synchronisation...');
        syncAll();
      } else {
        print('📴 Connexion perdue, mode hors-ligne');
      }
    });
  }
}
