// lib/services/fcm_notification_service.dart  (admin_lebontaxi_web_panel)
//
// VERSION MISE À JOUR — envoie push FCM + email en combiné.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_service.dart';

class FcmNotificationService {
  static final _supabase = Supabase.instance.client;

  /// Envoie une notification FCM + email au chauffeur.
  static Future<void> sendToDriver({
    required String driverId,
    required String type,
    required String title,
    required String body,
    Map<String, String> data = const {},
    // Paramètres optionnels pour l'email
    bool sendEmail = true,
    String? driverEmail,
    String? driverName,
    String? rejectionReason,
    String? documentLabel,
    bool isVehicleChange = false,
  }) async {
    // ── 1. Push FCM ──────────────────────────────────────────────────────────
    try {
      final row = await _supabase
          .from('drivers')
          .select('fcm_token, email, name')
          .eq('id', driverId)
          .maybeSingle();

      final fcmToken = row?['fcm_token']?.toString();
      final email    = driverEmail ?? row?['email']?.toString() ?? '';
      final name     = driverName  ?? row?['name']?.toString()  ?? 'Chauffeur';

      if (fcmToken != null && fcmToken.isNotEmpty) {
        final response = await _supabase.functions.invoke(
          'send-fcm-notification',
          body: {
            'token': fcmToken,
            'title': title,
            'body': body,
            'data': {'type': type, ...data},
          },
        );
        if (response.status != 200) {
          print('[FCM] ⚠️ Edge Function error: ${response.data}');
        } else {
          print('[FCM] ✅ Push envoyé à $driverId ($type)');
        }
      } else {
        print('[FCM] ℹ️ Pas de token FCM pour $driverId — push ignoré');
      }

      // ── 2. Email ────────────────────────────────────────────────────────────
      if (sendEmail && email.isNotEmpty) {
        switch (type) {
          case 'document_approved':
          case 'document_status_changed':
            // Vérifier si c'est une approbation complète
            if (data['document_status'] == 'approved' || type == 'document_approved') {
              await EmailService.sendApprovalEmail(
                driverEmail: email,
                driverName: name,
                isVehicleChange: isVehicleChange,
              );
            }
            break;

          case 'document_rejected':
            await EmailService.sendRejectionEmail(
              driverEmail: email,
              driverName: name,
              rejectionReason: rejectionReason ?? body,
              documentLabel: documentLabel,
              isVehicleChange: isVehicleChange,
            );
            break;

          case 'vehicle_change_received':
            await EmailService.sendVehicleChangeReceivedEmail(
              driverEmail: email,
              driverName: name,
              newCarModel: data['car_model'] ?? '',
              newCarNumber: data['car_number'] ?? '',
            );
            break;
        }
      }
    } catch (e) {
      print('[FCM] ❌ Erreur: $e');
    }
  }

  /// Broadcast à tous les chauffeurs (push uniquement).
  static Future<void> sendToAllDrivers({
    required String type,
    required String title,
    required String body,
    Map<String, String> data = const {},
  }) async {
    try {
      final rows = await _supabase
          .from('drivers')
          .select('id, fcm_token')
          .not('fcm_token', 'is', null);

      for (final row in rows) {
        final token = row['fcm_token']?.toString();
        final uid   = row['id']?.toString() ?? '';
        if (token == null || token.isEmpty) continue;

        await _supabase.functions.invoke(
          'send-fcm-notification',
          body: {
            'token': token,
            'title': title,
            'body': body,
            'data': {'type': type, ...data},
          },
        );
        print('[FCM] Broadcast → $uid');
      }
    } catch (e) {
      print('[FCM] Broadcast error: $e');
    }
  }
}
