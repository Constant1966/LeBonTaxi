import 'package:supabase_flutter/supabase_flutter.dart';

class EmailService {
  static final _supabase = Supabase.instance.client;

  /// Helper pour rÃ©cupÃ©rer les coordonnÃ©es de support
  static Future<Map<String, String>> _fetchSupportContact() async {
    try {
      final res = await _supabase
          .from('app_settings')
          .select('support_email, support_phone, support_whatsapp')
          .eq('id', 1)
          .maybeSingle();
      if (res != null) {
        return {
          'email': res['support_email']?.toString() ?? 'constantlorvenson@gmail.com',
          'phone': res['support_phone']?.toString() ?? '+50946894905',
          'whatsapp': res['support_whatsapp']?.toString() ?? 'https://wa.me/50946894905',
        };
      }
    } catch (_) {}
    return {
      'email': 'constantlorvenson@gmail.com',
      'phone': '+50946894905',
      'whatsapp': 'https://wa.me/50946894905',
    };
  }

  /// Email d'approbation totale du dossier.
  static Future<void> sendApprovalEmail({
    required String driverEmail,
    required String driverName,
    bool isVehicleChange = false,
  }) async {
    final subject = isVehicleChange
        ? 'âœ… Nouveau vÃ©hicule approuvÃ© â€” Le Bon Taxi'
        : 'âœ… Compte activÃ© â€” Le Bon Taxi';

    final contact = await _fetchSupportContact();
    final supportEmail = contact['email']!;

    final html = _buildHtml(
      title: isVehicleChange ? 'Nouveau vÃ©hicule approuvÃ© !' : 'Compte activÃ© !',
      driverName: driverName,
      iconEmoji: 'ðŸŽ‰',
      headerColor: '#10B981',
      body: isVehicleChange
          ? 'Les documents de votre <strong>nouveau vÃ©hicule</strong> ont Ã©tÃ© vÃ©rifiÃ©s et approuvÃ©s.<br><br>Votre compte est maintenant <strong>actif</strong>. Vous pouvez de nouveau recevoir des courses.'
          : 'FÃ©licitations ! Vos documents ont Ã©tÃ© approuvÃ©s.<br><br>Votre compte est maintenant <strong>actif</strong>. Vous pouvez commencer Ã  recevoir des courses.',
      callToAction: "Ouvrir l'application",
      supportEmail: supportEmail,
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
    final subject = 'Document rejetÃ©$docInfo â€” Le Bon Taxi';

    final contact = await _fetchSupportContact();
    final supportEmail = contact['email']!;
    final supportPhone = contact['phone']!;
    final supportWhatsapp = contact['whatsapp']!;

    final html = _buildHtml(
      title: 'Document rejetÃ©',
      driverName: driverName,
      iconEmoji: 'âŒ',
      headerColor: '#EF4444',
      body: '''${isVehicleChange ? 'Un document de votre <strong>nouveau vÃ©hicule</strong>' : 'Un de vos documents'}${documentLabel != null ? ' (<strong>$documentLabel</strong>)' : ''} n\'a pas pu Ãªtre validÃ©.<br><br>
<div style="background:#FEF2F2;border-left:4px solid #EF4444;padding:12px 16px;border-radius:0 8px 8px 0;margin:12px 0;">
  <strong>Motif :</strong> $rejectionReason
</div>
Veuillez ouvrir l\'application et <strong>re-soumettre</strong> ${documentLabel != null ? 'ce document' : 'les documents concernÃ©s'} en vous assurant que la photo est nette, lisible et que le document n\'est pas expirÃ©.''',
      callToAction: 'Re-soumettre mes documents',
      footer: 'Questions ? <a href="mailto:$supportEmail" style="color:#6366F1;">$supportEmail</a> ou <a href="$supportWhatsapp" style="color:#25D366;">WhatsApp $supportPhone</a>',
      supportEmail: supportEmail,
    );

    await _send(to: driverEmail, subject: subject, html: html);
  }

  /// Email de confirmation de rÃ©ception du changement de vÃ©hicule.
  static Future<void> sendVehicleChangeReceivedEmail({
    required String driverEmail,
    required String driverName,
    required String newCarModel,
    required String newCarNumber,
  }) async {
    const subject = 'Changement de vÃ©hicule reÃ§u â€” Le Bon Taxi';

    final contact = await _fetchSupportContact();
    final supportEmail = contact['email']!;

    final html = _buildHtml(
      title: 'Changement de vÃ©hicule reÃ§u',
      driverName: driverName,
      iconEmoji: 'ðŸ”„',
      headerColor: '#6366F1',
      body: '''Nous avons bien reÃ§u les documents de votre nouveau vÃ©hicule :<br><br>
<div style="background:#EEF2FF;border-left:4px solid #6366F1;padding:12px 16px;border-radius:0 8px 8px 0;margin:12px 0;">
  <strong>$newCarModel</strong> â€” Plaque : <strong>$newCarNumber</strong>
</div>
Votre dossier est <strong>en cours de vÃ©rification</strong> (24 Ã  48h).<br><br>
<em>Votre compte est temporairement suspendu pendant cette pÃ©riode.</em>''',
      callToAction: 'Voir le statut de mes documents',
      supportEmail: supportEmail,
    );

    await _send(to: driverEmail, subject: subject, html: html);
  }

  // â”€â”€ Core send â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
        print('[EmailService] âš ï¸ Erreur: ${response.data}');
      } else {
        print('[EmailService] âœ… Email envoyÃ© Ã  $to');
      }
    } catch (e) {
      print('[EmailService] âŒ Exception: $e');
    }
  }

  // â”€â”€ HTML template â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static String _buildHtml({
    required String title,
    required String driverName,
    required String iconEmoji,
    required String headerColor,
    required String body,
    String? callToAction,
    String? footer,
    String supportEmail = 'constantlorvenson@gmail.com',
  }) {
    final year = DateTime.now().year;
    
    final callToActionHtml = callToAction != null ? '''
          <table width="100%" cellpadding="0" cellspacing="0">
            <tr><td align="center" style="padding:8px 0 24px;">
              <a href="#" style="display:inline-block;background:$headerColor;color:#fff;font-weight:700;font-size:15px;padding:14px 32px;border-radius:10px;text-decoration:none;">$callToAction</a>
            </td></tr>
          </table>''' : '';
          
    final footerHtml = footer ?? 'Questions ? <a href="mailto:$supportEmail" style="color:#6366F1;">$supportEmail</a>';

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
          <span style="color:#fff;font-size:16px;font-weight:700;">ðŸš• Le Bon Taxi</span>
        </td></tr>

        <!-- Body -->
        <tr><td style="padding:32px 40px;">
          <p style="color:#374151;font-size:16px;margin:0 0 16px;">Bonjour <strong>$driverName</strong>,</p>
          <div style="color:#4B5563;font-size:15px;line-height:1.7;margin:0 0 24px;">$body</div>
$callToActionHtml
        </td></tr>

        <!-- Footer -->
        <tr><td style="padding:20px 40px;text-align:center;border-top:1px solid #E5E7EB;">
          <p style="color:#9CA3AF;font-size:13px;margin:0 0 6px;">
            $footerHtml
          </p>
          <p style="color:#9CA3AF;font-size:12px;margin:0;">Â© $year Le Bon Taxi â€” HaÃ¯ti</p>
        </td></tr>

      </table>
    </td></tr>
  </table>
</body>
</html>''';
  }
}
