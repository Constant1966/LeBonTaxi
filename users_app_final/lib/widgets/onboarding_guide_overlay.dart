import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
  });
}

class OnboardingGuideOverlay extends StatefulWidget {
  final VoidCallback onSkipOrFinish;

  const OnboardingGuideOverlay({super.key, required this.onSkipOrFinish});

  @override
  State<OnboardingGuideOverlay> createState() => _OnboardingGuideOverlayState();
}

class _OnboardingGuideOverlayState extends State<OnboardingGuideOverlay> {
  int _currentStep = 0;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: "Bienvenue sur Le Bon Taxi !",
      description: "Découvrez comment commander rapidement et facilement votre premier taxi.",
      icon: Icons.local_taxi_rounded,
      iconColor: AppColors.primary,
    ),
    OnboardingStep(
      title: "Recherche de Destination",
      description: "Saisissez votre destination ou recherchez des lieux pour estimer le tarif et commander une course.",
      icon: Icons.search_rounded,
      iconColor: Colors.green,
    ),
    OnboardingStep(
      title: "Menu de Navigation",
      description: "Ouvrez le menu latéral (en haut à gauche) pour gérer vos moyens de paiement, consulter vos parrainages, codes promos, et abonnements.",
      icon: Icons.menu_rounded,
      iconColor: Colors.blue,
    ),
    OnboardingStep(
      title: "Chauffeurs en Temps Réel",
      description: "Observez en temps réel sur la carte les chauffeurs disponibles autour de votre position géographique.",
      icon: Icons.map_rounded,
      iconColor: Colors.indigo,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.75),
      child: Stack(
        children: [
          // Bouton Passer en haut à droite
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: TextButton(
              onPressed: widget.onSkipOrFinish,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                "Passer",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Contenu au centre
          Center(
            child: Container(
              width: size.width * 0.85,
              constraints: const BoxConstraints(maxHeight: 450),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icône
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: step.iconColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      step.icon,
                      size: 56,
                      color: step.iconColor,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Titre
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    step.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Bouton Suivant et indicateurs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicateurs
                      Row(
                        children: List.generate(
                          _steps.length,
                          (index) => Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: _currentStep == index ? 18 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentStep == index
                                  ? AppColors.primary
                                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                            ),
                          ),
                        ),
                      ),

                      // Bouton Suivant / Terminer
                      ElevatedButton(
                        onPressed: () {
                          if (_currentStep < _steps.length - 1) {
                            setState(() {
                              _currentStep++;
                            });
                          } else {
                            widget.onSkipOrFinish();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          _currentStep == _steps.length - 1 ? "Terminer" : "Suivant",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
