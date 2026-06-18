import 'package:flutter/material.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color(0xFF1E1B4B) : const Color(0xFF6366F1),
        elevation: 0,
        title: const Text(
          "Politique de confidentialité",
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
                    child: const Icon(Icons.privacy_tip_rounded,
                        size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Politique de Confidentialité",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Dernière mise à jour : Juin 2025",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Introduction
                  _buildInfoBanner(
                    theme,
                    isDark,
                    Icons.shield_rounded,
                    "Votre vie privée est importante pour nous. Cette politique explique "
                        "comment Le Bon Taxi collecte, utilise et protège vos données personnelles.",
                  ),
                  const SizedBox(height: 20),

                  _buildSection(
                    theme,
                    isDark,
                    "1. Données collectées",
                    "Nous collectons les catégories de données suivantes :\n\n"
                        "📋 Informations d'identité :\n"
                        "• Nom complet et prénom\n"
                        "• Numéro de téléphone\n"
                        "• Adresse email\n"
                        "• Photo de profil\n\n"
                        "🚗 Informations sur le véhicule :\n"
                        "• Marque, modèle et couleur du véhicule\n"
                        "• Numéro de plaque d'immatriculation\n"
                        "• Photo du véhicule\n\n"
                        "📄 Documents officiels :\n"
                        "• Permis de conduire\n"
                        "• Carte d'assurance\n"
                        "• Carte grise\n\n"
                        "📍 Données de localisation :\n"
                        "• Position GPS en temps réel (lorsque vous êtes en ligne)\n"
                        "• Historique des trajets effectués\n\n"
                        "💰 Données financières :\n"
                        "• Historique des gains\n"
                        "• Modes de paiement utilisés",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "2. Utilisation des données",
                    "Vos données sont utilisées pour :\n\n"
                        "• Vous mettre en relation avec les passagers à proximité\n"
                        "• Calculer les itinéraires et estimer les temps de trajet\n"
                        "• Calculer et afficher vos gains\n"
                        "• Vérifier votre identité et vos documents\n"
                        "• Assurer la sécurité des passagers et des chauffeurs\n"
                        "• Améliorer la qualité du service\n"
                        "• Vous envoyer des notifications importantes (nouvelles courses, mises à jour)\n"
                        "• Gérer le support client et résoudre les litiges\n"
                        "• Respecter nos obligations légales",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "3. Partage des données",
                    "Vos données peuvent être partagées avec :\n\n"
                        "👤 Les passagers :\n"
                        "• Votre prénom, photo, note moyenne\n"
                        "• Informations sur votre véhicule (modèle, couleur, plaque)\n"
                        "• Votre position en temps réel pendant une course\n\n"
                        "🏢 Nos partenaires techniques :\n"
                        "• Supabase (hébergement des données)\n"
                        "• Services de cartographie (Google Maps)\n\n"
                        "⚖️ Autorités compétentes :\n"
                        "• En cas d'obligation légale\n"
                        "• En cas d'enquête suite à un incident de sécurité\n\n"
                        "Nous ne vendons jamais vos données personnelles à des tiers à des fins commerciales.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "4. Géolocalisation",
                    "L'application utilise votre position GPS pour :\n\n"
                        "• Vous affecter les courses les plus proches\n"
                        "• Permettre au passager de suivre votre arrivée\n"
                        "• Calculer la distance et le coût de la course\n"
                        "• Assurer la sécurité pendant le trajet\n\n"
                        "La géolocalisation est active uniquement lorsque vous êtes en mode \"En ligne\". "
                        "Vous pouvez désactiver le suivi de position à tout moment depuis les paramètres, "
                        "mais cela empêchera la réception de nouvelles courses.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "5. Sécurité des données",
                    "Nous prenons la protection de vos données très au sérieux :\n\n"
                        "🔒 Mesures de sécurité :\n"
                        "• Chiffrement des données en transit (HTTPS/TLS)\n"
                        "• Authentification sécurisée (OTP par SMS)\n"
                        "• Accès restreint aux données sensibles\n"
                        "• Surveillance continue des systèmes\n"
                        "• Sauvegarde régulière des données\n\n"
                        "Malgré nos efforts, aucun système n'est infaillible. "
                        "En cas de faille de sécurité affectant vos données, nous vous en informerons dans les meilleurs délais.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "6. Conservation des données",
                    "Vos données sont conservées :\n\n"
                        "• Données du compte : tant que votre compte est actif\n"
                        "• Historique des courses : 24 mois après la course\n"
                        "• Données de géolocalisation : 12 mois\n"
                        "• Documents (permis, assurance) : durée de validité + 6 mois\n\n"
                        "Après suppression de votre compte, vos données personnelles seront effacées dans un délai de 30 jours, "
                        "sauf obligation légale de conservation.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "7. Vos droits",
                    "Vous disposez des droits suivants concernant vos données :\n\n"
                        "✅ Droit d'accès : consulter vos données personnelles\n"
                        "✏️ Droit de rectification : corriger des informations inexactes\n"
                        "🗑️ Droit de suppression : supprimer votre compte et vos données\n"
                        "📦 Droit de portabilité : obtenir une copie de vos données\n"
                        "🚫 Droit d'opposition : refuser certains traitements\n\n"
                        "Pour exercer ces droits, contactez-nous par email ou WhatsApp.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "8. Cookies et technologies similaires",
                    "L'application peut utiliser des technologies de stockage local pour :\n\n"
                        "• Mémoriser vos préférences (thème, notifications)\n"
                        "• Améliorer les performances de l'application\n"
                        "• Stocker des données hors ligne (cache SQLite)\n\n"
                        "Ces données restent sur votre appareil et ne sont pas partagées avec des tiers.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "9. Modifications de cette politique",
                    "Nous pouvons mettre à jour cette politique de confidentialité de temps à autre. "
                        "Les modifications importantes vous seront notifiées via l'application. "
                        "Nous vous encourageons à consulter régulièrement cette page pour rester informé.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "10. Contact",
                    "Pour toute question concernant la confidentialité de vos données, contactez-nous :\n\n"
                        "📧 Email : constantlorvenson@gmail.com\n"
                        "📞 Téléphone : +509 46 89 49 05\n"
                        "💬 WhatsApp : +509 46 89 49 05",
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

  Widget _buildInfoBanner(
      ThemeData theme, bool isDark, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF312E81).withOpacity(0.4)
            : const Color(0xFF6366F1).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF4F46E5).withOpacity(0.3)
              : const Color(0xFF6366F1).withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF4F46E5).withOpacity(0.3)
                  : const Color(0xFF6366F1).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: isDark
                    ? const Color(0xFF818CF8)
                    : const Color(0xFF4F46E5),
                size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      ThemeData theme, bool isDark, String title, String content) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? const Color(0xFF818CF8)
                  : const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
