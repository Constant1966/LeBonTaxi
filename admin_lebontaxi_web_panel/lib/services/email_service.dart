// lib/services/email_service.dart  (admin_lebontaxi_web_panel)
//
// Adapté pour l'Edge Function Supabase avec le format :
//   { to, subject, html }
// ─────────────────────────────────────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  static final _supabase = Supabase.instance.client;

  /// Email d'approbation totale du dossier.
  static Future<void> sendApprovalEmail({
    required String driverEmail,
    required String driverName,
    bool isVehicleChange = false,
  }) async {
    final subject = isVehicleChange
        ? '✅ Nouveau véhicule approuvé — Le Bon Taxi'
        : '✅ Compte activé — Le Bon Taxi';

    final html = _buildHtml(
      title: isVehicleChange ? 'Nouveau véhicule approuvé !' : 'Compte activé !',
      driverName: driverName,
      iconEmoji: '🎉',
      headerColor: '#10B981',
      body: isVehicleChange
          ? 'Les documents de votre <strong>nouveau véhicule</strong> ont été vérifiés et approuvés.<br><br>Votre compte est maintenant <strong>actif</strong>. Vous pouvez de nouveau recevoir des courses.'
          : 'Félicitations ! Vos documents ont été approuvés.<br><br>Votre compte est maintenant <strong>actif</strong>. Vous pouvez commencer à recevoir des courses.',
      callToAction: "Ouvrir l'application",
    );

    await _send(to: driverEmail, subject: subject, html: html);
  }

  /// Email de rejet d'un document.
  static Future<void> sendRejectionEmail({
    required String driverEmail,
    required String driverName,
    required String rejectionReason,
    String? documentLabel,
    bool isVehicleChange = false,
  }) async {
    final docInfo = documentLabel != null ? ' ($documentLabel)' : '';
    final subject = 'Document rejeté$docInfo — Le Bon Taxi';

    final html = _buildHtml(
      title: 'Document rejeté',
      driverName: driverName,
      iconEmoji: '❌',
      headerColor: '#EF4444',
      body: '''${isVehicleChange ? 'Un document de votre <strong>nouveau véhicule</strong>' : 'Un de vos documents'}${documentLabel != null ? ' (<strong>$documentLabel</strong>)' : ''} n\'a pas pu être validé.<br><br>
<div style="background:#FEF2F2;border-left:4px solid #EF4444;padding:12px 16px;border-radius:0 8px 8px 0;margin:12px 0;">
  <strong>Motif :</strong> $rejectionReason
</div>
Veuillez ouvrir l\'application et <strong>re-soumettre</strong> ${documentLabel != null ? 'ce document' : 'les documents concernés'} en vous assurant que la photo est nette, lisible et que le document n\'est pas expiré.''',
      callToAction: 'Re-soumettre mes documents',
      footer: 'Questions ? <a href="mailto:constantlorvenson@gmail.com" style="color:#6366F1;">constantlorvenson@gmail.com</a> ou <a href="https://wa.me/50946894905" style="color:#25D366;">WhatsApp +509 46 89 49 05</a>',
    );

    await _send(to: driverEmail, subject: subject, html: html);
  }

  /// Email de confirmation de réception du changement de véhicule.
  static Future<void> sendVehicleChangeReceivedEmail({
    required String driverEmail,
    required String driverName,
    required String newCarModel,
    required String newCarNumber,
  }) async {
    const subject = 'Changement de véhicule reçu — Le Bon Taxi';

    final html = _buildHtml(
      title: 'Changement de véhicule reçu',
      driverName: driverName,
      iconEmoji: '🔄',
      headerColor: '#6366F1',
      body: '''Nous avons bien reçu les documents de votre nouveau véhicule :<br><br>
<div style="background:#EEF2FF;border-left:4px solid #6366F1;padding:12px 16px;border-radius:0 8px 8px 0;margin:12px 0;">
  <strong>$newCarModel</strong> — Plaque : <strong>$newCarNumber</strong>
</div>
Votre dossier est <strong>en cours de vérification</strong> (24 à 48h).<br><br>
<em>Votre compte est temporairement suspendu pendant cette période.</em>''',
      callToAction: 'Voir le statut de mes documents',
    );

    await _send(to: driverEmail, subject: subject, html: html);
  }

  // ── Core send ──────────────────────────────────────────────────────────────

  static Future<void> _send({
    required String to,
    required String subject,
    required String html,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'send-driver-email',
        body: {
          'to': to,
          'subject': subject,
          'html': html,
        },
      );
      if (response.status != 200) {
        print('[EmailService] ⚠️ Erreur: ${response.data}');
      } else {
        print('[EmailService] ✅ Email envoyé à $to');
      }
    } catch (e) {
      print('[EmailService] ❌ Exception: $e');
    }
  }

  // ── HTML template ──────────────────────────────────────────────────────────

  static String _buildHtml({
    required String title,
    required String driverName,
    required String iconEmoji,
    required String headerColor,
    required String body,
    String? callToAction,
    String? footer,
  }) {
    final year = DateTime.now().year;
    return '''<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>$title</title>
</head>
<body style="margin:0;padding:0;background:#F3F4F6;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:40px 20px;">
    <tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

        <!-- Header -->
        <tr><td style="background:$headerColor;padding:32px 40px;text-align:center;">
          <div style="font-size:48px;margin-bottom:12px;">$iconEmoji</div>
          <h1 style="color:#fff;margin:0;font-size:22px;font-weight:700;">$title</h1>
        </td></tr>

        <!-- Brand -->
        <tr><td style="background:#1E1B4B;padding:10px 40px;text-align:center;">
          <span style="color:#fff;font-size:16px;font-weight:700;">🚕 Le Bon Taxi</span>
        </td></tr>

        <!-- Body -->
        <tr><td style="padding:32px 40px;">
          <p style="color:#374151;font-size:16px;margin:0 0 16px;">Bonjour <strong>$driverName</strong>,</p>
          <div style="color:#4B5563;font-size:15px;line-height:1.7;margin:0 0 24px;">$body</div>
          ${callToAction != null ? '''
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td align="center" style="padding:8px 0 24px;">
              <a href="#" style="display:inline-block;background:$headerColor;color:#fff;font-weight:700;font-size:15px;padding:14px 32px;border-radius:10px;text-decoration:none;">$callToAction</a>
            </td></tr>
          </table>''' : ''}
        </td></tr>

        <!-- Footer -->
        <tr><td style="padding:20px 40px;text-align:center;border-top:1px solid #E5E7EB;">
          <p style="color:#9CA3AF;font-size:13px;margin:0 0 6px;">
            ${footer ?? 'Questions ? <a href="mailto:constantlorvenson@gmail.com" style="color:#6366F1;">constantlorvenson@gmail.com</a>'}
          </p>
          <p style="color:#9CA3AF;font-size:12px;margin:0;">© $year Le Bon Taxi — Haïti</p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>''';
  }
}