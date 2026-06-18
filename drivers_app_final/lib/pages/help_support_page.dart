import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:drivers_app/theme/app_colors.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1B4B) : const Color(0xFF6366F1),
        elevation: 0,
        title: const Text(
          "Aide & Support",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
                      : [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.help_outline,
                        size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Comment pouvons-nous vous aider?",
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Actions rapides",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAction(
                          context,
                          "Appeler\nSupport",
                          Icons.phone,
                          const Color(0xFF10B981),
                          () => _makePhoneCall("+50946894905"),
                          theme,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickAction(
                          context,
                          "WhatsApp",
                          Icons.chat,
                          const Color(0xFF25D366),
                          () => _openWhatsApp("+50946894905"),
                          theme,
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickAction(
                          context,
                          "Email",
                          Icons.email,
                          AppColors.primary,
                          () => _sendEmail("constantlorvenson@gmail.com"),
                          theme,
                          isDark,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Text(
                    "Questions fréquentes",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildFAQItem(
                    "Comment accepter une course?",
                    "Lorsqu'une demande de course arrive, vous recevrez une notification. "
                    "Appuyez sur 'ACCEPTER' pour accepter la course. Vous avez 20 secondes pour répondre.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Comment fonctionne le paiement?",
                    "À la fin de chaque course, vous pouvez sélectionner le mode de paiement: "
                    "Espèces, MonCash ou NatCash. Le montant sera ajouté à vos gains.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Comment mettre à jour mon profil?",
                    "Allez dans Profil > Icône Paramètres (en haut à droite) > Modifier vos informations.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Que faire si j'ai un problème avec un client?",
                    "Contactez immédiatement notre support via téléphone ou WhatsApp. "
                    "Nous sommes disponibles 24/7 pour vous aider.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Comment voir mon historique de courses?",
                    "Allez dans l'onglet 'Courses' > 'Historique des courses' pour voir toutes vos courses terminées.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Comment fonctionne l'abonnement?",
                    "Le Bon Taxi propose différents plans d'abonnement pour les chauffeurs. "
                    "Accédez à la section 'Abonnement' depuis le menu principal pour voir les plans disponibles, "
                    "leurs avantages et les tarifs. Vous pouvez payer via MonCash ou NatCash. "
                    "Un abonnement actif est nécessaire pour recevoir des courses.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Comment consulter mes gains?",
                    "Vos gains sont visibles dans l'onglet 'Gains' du menu principal. "
                    "Vous y trouverez :\n"
                    "• Vos gains du jour, de la semaine et du mois\n"
                    "• Le détail de chaque course\n"
                    "• Un graphique de vos performances\n"
                    "Les gains sont mis à jour en temps réel après chaque course.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Comment soumettre mes documents?",
                    "Lors de votre inscription ou depuis votre profil, vous devez soumettre :\n"
                    "• Votre permis de conduire (recto/verso)\n"
                    "• L'assurance de votre véhicule\n"
                    "• La carte grise du véhicule\n\n"
                    "Les documents sont vérifiés par notre équipe sous 24 à 48 heures. "
                    "Vous recevrez une notification une fois vos documents approuvés.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Comment changer de véhicule?",
                    "Pour mettre à jour les informations de votre véhicule, allez dans "
                    "Paramètres > Section Photos > Véhicule. "
                    "Pour modifier le modèle, la couleur ou la plaque d'immatriculation, "
                    "contactez notre support via WhatsApp ou email.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Comment fonctionne le système de notes?",
                    "Après chaque course, les passagers peuvent vous attribuer une note de 1 à 5 étoiles. "
                    "Votre note moyenne est visible sur votre profil. "
                    "Une note élevée augmente vos chances de recevoir des courses. "
                    "Si votre note descend en dessous du seuil minimum, votre compte pourrait être suspendu.",
                    theme,
                    isDark,
                  ),
                  _buildFAQItem(
                    "Que faire si l'application ne fonctionne pas?",
                    "Essayez ces étapes :\n"
                    "1. Vérifiez votre connexion Internet\n"
                    "2. Activez le GPS de votre téléphone\n"
                    "3. Fermez et relancez l'application\n"
                    "4. Mettez à jour l'application depuis le Play Store\n"
                    "5. Redémarrez votre téléphone\n\n"
                    "Si le problème persiste, contactez notre support.",
                    theme,
                    isDark,
                  ),

                  const SizedBox(height: 32),

                  // Emergency Contact
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.red.shade900.withOpacity(0.3)
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: isDark
                              ? Colors.red.shade800
                              : Colors.red.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100.withOpacity(
                                    isDark ? 0.3 : 1.0),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.emergency,
                                  color: Colors.red.shade700),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text("Urgence",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.bodyLarge?.color)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "En cas d'urgence, contactez immédiatement:",
                          style: TextStyle(
                              fontSize: 14,
                              color: theme.textTheme.bodyMedium?.color),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _makePhoneCall("114"),
                            icon: const Icon(Icons.phone),
                            label: const Text(
                              "Appeler le 114 (Police)",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
    ThemeData theme,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.3,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(
      String question, String answer, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            question,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                answer,
                style: TextStyle(
                  color: theme.textTheme.bodySmall?.color,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    final Uri launchUri = Uri.parse('https://wa.me/$phoneNumber');
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendEmail(String email) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=Support Le Bon Taxi',
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }
}
