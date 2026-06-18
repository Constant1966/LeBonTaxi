// lib/services/push_notification_document_handler.dart
//
// Ajoutez ce code dans votre push_notification_system.dart existant.
// Gère les notifications FCM de type 'document_rejected' et 'document_approved'.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Mixin / helper à intégrer dans votre PushNotificationSystem existant.
/// Appelle [handleDocumentNotification] depuis votre handler FCM principal.
class DocumentNotificationHandler {
  /// À appeler depuis votre handler `FirebaseMessaging.onMessage.listen(...)`.
  static Future<void> handleDocumentNotification(
    RemoteMessage message,
    BuildContext context,
  ) async {
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'document_rejected') {
      await _showDocumentRejectedDialog(context, data);
    } else if (type == 'document_approved') {
      _showDocumentApprovedSnackbar(context, data);
    } else if (type == 'document_status_changed') {
      _showStatusChangedSnackbar(context, data);
    }
  }

  // ── Rejected dialog ──────────────────────────────────────────────────────

  static Future<void> _showDocumentRejectedDialog(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final String docType = data['document_type'] ?? 'document';
    final String docLabel = data['document_label'] ?? _labelFor(docType);
    final String reason = data['rejection_reason'] ?? 'Non spécifié';
    final String? documentId = data['document_id'] as String?;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Document rejeté',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Votre document "$docLabel" a été rejeté.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Motif du rejet :',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(reason, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to document status page
              Navigator.pushNamed(context, '/document-status',
                  arguments: {'highlight_document_id': documentId});
            },
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Remplacer maintenant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Approved snackbar ────────────────────────────────────────────────────

  static void _showDocumentApprovedSnackbar(
      BuildContext context, Map<String, dynamic> data) {
    final docLabel =
        data['document_label'] ?? _labelFor(data['document_type'] ?? '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('✅ "$docLabel" approuvé !')),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Voir',
          textColor: Colors.white,
          onPressed: () =>
              Navigator.pushNamed(context, '/document-status'),
        ),
      ),
    );
  }

  static void _showStatusChangedSnackbar(
      BuildContext context, Map<String, dynamic> data) {
    final status = data['document_status'] ?? '';
    final msg = status == 'approved'
        ? 'Votre profil a été approuvé ! Vous pouvez accepter des courses.'
        : 'Le statut de vos documents a changé.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
    );
  }

  static String _labelFor(String type) {
    const Map<String, String> labels = {
      'drivers_license': 'Permis de conduire',
      'criminal_record': 'Casier judiciaire',
      'identity_card': 'Carte d\'identité',
      'vehicle_registration': 'Carte grise',
      'vehicle_insurance': 'Assurance véhicule',
      'tdc_permit': 'Permis TDC',
      'technical_inspection': 'Visite technique',
      'other': 'Autre document',
    };
    return labels[type] ?? type;
  }
}
