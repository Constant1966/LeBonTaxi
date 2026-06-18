import 'package:flutter/material.dart';
import 'package:users_app/theme/app_colors.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Politique de Confidentialité",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.success, Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.security, color: Colors.white, size: 40),
                  SizedBox(height: 12),
                  Text(
                    "Politique de Confidentialité",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Dernière mise à jour : 15 Juin 2026",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Policy Sections
            _buildSection(
              isDark: isDark,
              icon: Icons.info_outline,
              title: "1. Collecte des informations",
              content: "Nous recueillons des informations lorsque vous créez un compte et utilisez nos services. Cela comprend :\n"
                  "• Données d'identification : Nom, email, mot de passe, NIN (Numéro d'Identification National) et photo de profil.\n"
                  "• Coordonnées : Numéro de téléphone et informations du contact d'urgence (nom et numéro).\n"
                  "• Données de localisation : Nous collectons votre position précise en temps réel afin de vous géolocaliser pour le départ, de calculer l'itinéraire de votre course et de suivre le trajet en cours.",
            ),
            _buildSection(
              isDark: isDark,
              icon: Icons.visibility,
              title: "2. Utilisation des données",
              content: "Vos données sont traitées pour les finalités suivantes :\n"
                  "• Mise en relation avec les chauffeurs à proximité.\n"
                  "• Calcul automatique des tarifs, des distances et de la durée estimée (ETA).\n"
                  "• Envoi de notifications push concernant le statut de votre trajet.\n"
                  "• Sécurité renforcée : Envoi de SMS ou partage de trajet en temps réel avec votre contact de confiance en cas d'urgence.",
            ),
            _buildSection(
              isDark: isDark,
              icon: Icons.share_arrival_time,
              title: "3. Partage des informations",
              content: "Le Bon Taxi ne vend ni ne loue vos informations personnelles. Vos données sont uniquement partagées avec :\n"
                  "• Les chauffeurs acceptant votre course (uniquement votre nom, photo, téléphone et points de départ/arrivée pour le bon déroulement du service).\n"
                  "• Vos proches via le partage manuel de course ou en cas d'activation du bouton d'urgence (SOS).",
            ),
            _buildSection(
              isDark: isDark,
              icon: Icons.storage,
              title: "4. Conservation et Suppression",
              content: "Nous conservons vos données aussi longtemps que votre compte reste actif. Vous disposez d'un droit de consultation, de rectification et de suppression totale de vos informations. Vous pouvez à tout moment supprimer définitivement votre compte depuis l'écran Paramètres de l'application.",
            ),
            _buildSection(
              isDark: isDark,
              icon: Icons.enhanced_encryption,
              title: "5. Sécurité des données",
              content: "Nous mettons en œuvre des mesures de sécurité physiques, électroniques et administratives pour protéger vos informations contre tout accès non autorisé, altération, divulgation ou destruction. Toutes les communications sensibles avec nos serveurs Supabase sont chiffrées (SSL/TLS).",
            ),

            const SizedBox(height: 20),
            Center(
              child: Text(
                "Pour toute question relative à vos données : privacy@lebontaxi.com",
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required bool isDark,
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
        border: isDark ? Border.all(color: Colors.grey.shade800) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.success, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
