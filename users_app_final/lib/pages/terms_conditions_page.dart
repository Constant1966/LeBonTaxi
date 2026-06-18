import 'package:flutter/material.dart';
import 'package:users_app/theme/app_colors.dart';

class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Conditions d'Utilisation",
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
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gavel, color: Colors.white, size: 40),
                  SizedBox(height: 12),
                  Text(
                    "Conditions Générales d'Utilisation",
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

            // Content Articles
            _buildSection(
              isDark: isDark,
              number: "1",
              title: "Acceptation des Conditions",
              content: "En téléchargeant, installant ou utilisant l'application Le Bon Taxi, vous acceptez d'être lié sans réserve par les présentes Conditions Générales d'Utilisation (CGU). Si vous n'acceptez pas ces termes, veuillez désinstaller l'application.",
            ),
            _buildSection(
              isDark: isDark,
              number: "2",
              title: "Services proposés",
              content: "Le Bon Taxi est une plateforme technologique mettant en relation des passagers et des chauffeurs de taxi indépendants. Le Bon Taxi n'est pas un transporteur routier et ne fournit pas de services de transport par lui-même.",
            ),
            _buildSection(
              isDark: isDark,
              number: "3",
              title: "Création de compte et sécurité",
              content: "Pour utiliser nos services, vous devez créer un compte valide en fournissant des informations véridiques (Nom complet, NIN, Téléphone, Photo). Vous êtes responsable de la sécurité de vos identifiants et de toutes les activités effectuées sur votre compte. L'accès des mineurs non accompagnés est interdit.",
            ),
            _buildSection(
              isDark: isDark,
              number: "4",
              title: "Tarification et Abonnements",
              content: "Les tarifs des courses sont calculés dynamiquement selon la distance et les conditions de circulation. Le Bon Taxi propose également des forfaits d'abonnement (Le Bon Taxi Plus) octroyant des réductions sur les courses. Les abonnements sont payables d'avance et non remboursables.",
            ),
            _buildSection(
              isDark: isDark,
              number: "5",
              title: "Comportement de l'utilisateur",
              content: "Vous vous engagez à respecter le chauffeur, son véhicule et le code de la route. Tout comportement offensant, harcèlement, dégradation de véhicule ou fausse déclaration entraînera la suspension ou la suppression immédiate de votre compte.",
            ),
            _buildSection(
              isDark: isDark,
              number: "6",
              title: "Responsabilité et Force majeure",
              content: "Le Bon Taxi s'efforce de maintenir la plateforme accessible 24/7 mais ne peut garantir l'absence de pannes techniques. Nous ne saurions être tenus responsables des différends physiques, retards, pertes d'objets ou dommages survenus pendant le transport assuré par les chauffeurs indépendants.",
            ),
            _buildSection(
              isDark: isDark,
              number: "7",
              title: "Modification des conditions",
              content: "Le Bon Taxi se réserve le droit de modifier les présentes CGU à tout moment. Les modifications entreront en vigueur dès leur publication dans l'application.",
            ),
            
            const SizedBox(height: 20),
            Center(
              child: Text(
                "Pour toute assistance : support@lebontaxi.com",
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
    required String number,
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
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
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
