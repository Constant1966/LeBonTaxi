import 'package:flutter/material.dart';
import 'package:users_app/theme/app_colors.dart';

class SafetyGuidelinesPage extends StatelessWidget {
  const SafetyGuidelinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: const Text(
          "Conseils de Sécurité",
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
                  colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE53935).withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield, color: Colors.white, size: 40),
                  SizedBox(height: 12),
                  Text(
                    "Votre Sécurité est notre Priorité",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Voici les bonnes pratiques pour voyager l'esprit tranquille.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Step 1: Avant le départ
            _buildSafetyStep(
              isDark: isDark,
              stepNumber: "1",
              stepTitle: "Avant de monter à bord",
              stepColor: AppColors.info,
              points: [
                "Vérifiez l'identité du chauffeur : correspond-il à la photo affichée dans votre application ?",
                "Vérifiez le véhicule : le modèle, la couleur et la plaque d'immatriculation doivent être identiques aux informations indiquées sur votre écran.",
                "Confirmez la destination : demandez au chauffeur le nom du passager avant de monter à bord.",
              ],
            ),

            // Step 2: Pendant le trajet
            _buildSafetyStep(
              isDark: isDark,
              stepNumber: "2",
              stepTitle: "Pendant le trajet",
              stepColor: AppColors.success,
              points: [
                "Partagez votre course : utilisez le bouton 'Partager ma course' pour envoyer à vos proches un lien de suivi en direct de votre position.",
                "Suivez l'itinéraire : gardez un œil sur la carte de l'application pour vous assurer que le chauffeur suit le bon chemin.",
                "Portez votre ceinture de sécurité : c'est obligatoire pour votre protection en cas de collision.",
              ],
            ),

            // Step 3: En cas d'urgence
            _buildSafetyStep(
              isDark: isDark,
              stepNumber: "3",
              stepTitle: "En cas d'urgence",
              stepColor: const Color(0xFFE53935),
              points: [
                "Utilisez le bouton SOS / Urgence : accessible en un clic sur l'écran d'accueil ou la carte chauffeur pour appeler la police (114) ou d'autres services.",
                "Alertez votre contact d'urgence : déclenchez l'envoi d'un SMS SOS pré-rempli contenant votre position actuelle et les détails de la course.",
                "Restez calme et à l'abri : si vous vous sentez en danger, demandez au chauffeur de s'arrêter dans un lieu public et éclairé pour descendre.",
              ],
            ),

            // Step 4: Après le trajet
            _buildSafetyStep(
              isDark: isDark,
              stepNumber: "4",
              stepTitle: "Après l'arrivée",
              stepColor: AppColors.accent,
              points: [
                "Notez votre course : donnez une note honnête au chauffeur et ajoutez des commentaires. Cela nous aide à maintenir une communauté de confiance.",
                "Signalez les problèmes : en cas de comportement inapproprié ou de conduite dangereuse, contactez le support immédiatement.",
              ],
            ),

            const SizedBox(height: 10),
            Center(
              child: Text(
                "Le Bon Taxi — Voyagez sereinement.",
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyStep({
    required bool isDark,
    required String stepNumber,
    required String stepTitle,
    required Color stepColor,
    required List<String> points,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        border: Border.all(color: stepColor.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: stepColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  stepTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...points.map((point) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, color: stepColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
