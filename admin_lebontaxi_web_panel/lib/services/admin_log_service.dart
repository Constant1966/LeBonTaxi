import 'package:supabase_flutter/supabase_flutter.dart';

/// Service centralisé pour logger chaque action admin dans la table `admin_logs`.
/// Appelé depuis chaque page lors d'une action significative.
class AdminLogService {
  static final _supabase = Supabase.instance.client;

  /// Log une action admin dans la base de données.
  ///
  /// [action] : Description de l'action (ex: "Bloquer chauffeur")
  /// [targetType] : Type de cible (ex: "driver", "user", "pricing", "discount", "message")
  /// [targetId] : ID de la cible (ex: ID du chauffeur bloqué)
  /// [details] : Détails supplémentaires (Map libre)
  static Future<void> log({
    required String action,
    String? targetType,
    String? targetId,
    Map<String, dynamic>? details,
  }) async {
    try {
      final adminEmail = _supabase.auth.currentUser?.email ?? 'unknown';
      await _supabase.from('admin_logs').insert({
        'admin_email': adminEmail,
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
        'details': details,
      });
    } catch (e) {
      // On ne veut pas que le logging plante l'action principale
      print('AdminLogService error: $e');
    }
  }
}
