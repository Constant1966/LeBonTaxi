import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

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
          "Conditions d'utilisation",
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
                    child: const Icon(Icons.article_rounded,
                        size: 48, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Conditions Générales d'Utilisation",
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
                  _buildSection(
                    theme,
                    isDark,
                    "1. Acceptation des conditions",
                    "En téléchargeant, installant ou utilisant l'application Le Bon Taxi Chauffeur, "
                        "vous acceptez d'être lié par les présentes Conditions Générales d'Utilisation (CGU). "
                        "Si vous n'acceptez pas ces conditions, veuillez ne pas utiliser l'application.\n\n"
                        "Le Bon Taxi se réserve le droit de modifier ces conditions à tout moment. "
                        "Les modifications prendront effet dès leur publication dans l'application.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "2. Description du service",
                    "Le Bon Taxi est une plateforme de mise en relation entre chauffeurs et passagers en Haïti. "
                        "L'application permet aux chauffeurs enregistrés de :\n\n"
                        "• Recevoir et accepter des demandes de course\n"
                        "• Naviguer vers les points de prise en charge et de destination\n"
                        "• Gérer leurs gains et historique de courses\n"
                        "• Communiquer avec les passagers via le chat intégré\n\n"
                        "Le Bon Taxi agit uniquement en tant qu'intermédiaire technologique et ne fournit pas directement de services de transport.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "3. Inscription et compte chauffeur",
                    "Pour utiliser l'application en tant que chauffeur, vous devez :\n\n"
                        "• Être âgé d'au moins 18 ans\n"
                        "• Posséder un permis de conduire valide en Haïti\n"
                        "• Disposer d'un véhicule en bon état et assuré\n"
                        "• Fournir des informations exactes et à jour lors de l'inscription\n"
                        "• Soumettre les documents requis (permis, assurance, carte grise)\n\n"
                        "Vous êtes responsable de la confidentialité de vos identifiants de connexion. "
                        "Toute activité effectuée sous votre compte relève de votre responsabilité.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "4. Obligations du chauffeur",
                    "En tant que chauffeur Le Bon Taxi, vous vous engagez à :\n\n"
                        "• Respecter le Code de la route haïtien en tout temps\n"
                        "• Maintenir votre véhicule en état de fonctionnement sûr et propre\n"
                        "• Traiter les passagers avec respect et courtoisie\n"
                        "• Suivre l'itinéraire le plus efficace sauf indication contraire du passager\n"
                        "• Ne pas annuler de courses de manière excessive ou abusive\n"
                        "• Ne pas conduire sous l'influence de l'alcool ou de substances illicites\n"
                        "• Maintenir une assurance valide pour votre véhicule\n"
                        "• Respecter les tarifs fixés par la plateforme",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "5. Tarification et paiements",
                    "Les tarifs des courses sont calculés automatiquement par l'application en fonction de :\n\n"
                        "• La distance parcourue\n"
                        "• Le temps estimé du trajet\n"
                        "• Le type de véhicule\n"
                        "• La demande en temps réel (tarification dynamique)\n\n"
                        "Les modes de paiement acceptés sont : Espèces, MonCash et NatCash. "
                        "Le Bon Taxi peut prélever une commission sur chaque course effectuée. "
                        "Les gains sont mis à jour en temps réel dans votre tableau de bord.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "6. Abonnements",
                    "L'utilisation de certaines fonctionnalités de l'application peut nécessiter un abonnement actif. "
                        "Les détails des plans d'abonnement, y compris les tarifs et les avantages, "
                        "sont disponibles dans la section 'Abonnement' de l'application.\n\n"
                        "Le non-renouvellement de votre abonnement peut entraîner une limitation de l'accès "
                        "aux fonctionnalités de la plateforme.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "7. Suspension et résiliation",
                    "Le Bon Taxi se réserve le droit de suspendre ou résilier votre compte en cas de :\n\n"
                        "• Violation des présentes CGU\n"
                        "• Comportement inapproprié ou dangereux signalé par les passagers\n"
                        "• Note moyenne inférieure au seuil minimum requis\n"
                        "• Fraude ou tentative de fraude\n"
                        "• Fourniture d'informations fausses ou trompeuses\n"
                        "• Inactivité prolongée sans notification préalable\n\n"
                        "Vous pouvez à tout moment supprimer votre compte via les paramètres de l'application.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "8. Responsabilité",
                    "Le Bon Taxi ne peut être tenu responsable :\n\n"
                        "• Des dommages directs ou indirects résultant de l'utilisation de l'application\n"
                        "• Des accidents survenus pendant les courses\n"
                        "• Des différends entre chauffeurs et passagers\n"
                        "• Des pannes techniques ou interruptions de service\n\n"
                        "Le chauffeur est seul responsable de la conduite de son véhicule et de la sécurité des passagers.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "9. Propriété intellectuelle",
                    "L'application Le Bon Taxi, y compris son design, ses logos, ses textes et son code source, "
                        "est protégée par les lois sur la propriété intellectuelle. "
                        "Toute reproduction, distribution ou utilisation non autorisée est strictement interdite.",
                  ),
                  _buildSection(
                    theme,
                    isDark,
                    "10. Contact",
                    "Pour toute question relative aux présentes conditions, vous pouvez nous contacter :\n\n"
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
