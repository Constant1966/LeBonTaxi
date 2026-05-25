import 'package:flutter/material.dart';

/// Système de couleurs cohérent pour toute l'application Le Bon Taxi
class AppColors {
  // Couleurs Primaires
  static const Color primary = Color(0xFF6366F1); // Indigo
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);

  // Couleurs Secondaires
  static const Color secondary = Color(0xFF8B5CF6); // Purple
  static const Color secondaryDark = Color(0xFF7C3AED);
  static const Color secondaryLight = Color(0xFFA78BFA);

  // Couleurs d'Accent
  static const Color accent = Color(0xFFEC4899); // Pink
  static const Color accentDark = Color(0xFFDB2777);
  static const Color accentLight = Color(0xFFF472B6);

  // Couleurs de Status
  static const Color success = Color(0xFF10B981); // Green
  static const Color successDark = Color(0xFF059669);
  static const Color successLight = Color(0xFF34D399);

  static const Color warning = Color(0xFFF59E0B); // Orange
  static const Color warningDark = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFBBF24);

  static const Color error = Color(0xFFEF4444); // Red
  static const Color errorDark = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFF87171);

  static const Color info = Color(0xFF3B82F6); // Blue
  static const Color infoDark = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFF60A5FA);

  // Couleurs de Texte
  static const Color textPrimary = Color(0xFF1F2937); // Gris très foncé
  static const Color textSecondary = Color(0xFF6B7280); // Gris moyen
  static const Color textTertiary = Color(0xFF9CA3AF); // Gris clair
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDisabled = Color(0xFFD1D5DB);

  // Couleurs de Fond
  static const Color background = Color(0xFFFAFAFA); // Gris très clair
  static const Color backgroundLight = Color(0xFFFFFFFF); // Blanc
  static const Color backgroundDark = Color(0xFFF3F4F6); // Gris clair
  static const Color backgroundCard = Color(0xFFFFFFFF);

  // Couleurs de Bordure
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFFD1D5DB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // Couleurs pour les états Online/Offline
  static const Color online = success;
  static const Color offline = Color(0xFF6B7280);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, Color(0xFF059669)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, secondary],
  );

  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
  );

  // Ombres
  static BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 10,
    spreadRadius: 0,
    offset: const Offset(0, 2),
  );

  static BoxShadow elevatedShadow = BoxShadow(
    color: Colors.black.withOpacity(0.1),
    blurRadius: 15,
    spreadRadius: 2,
    offset: const Offset(0, 4),
  );

  // Méthodes utilitaires
  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }

  static Color lighten(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  static Color darken(Color color, [double amount = 0.1]) {
    final hsl = HSLColor.fromColor(color);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }
}