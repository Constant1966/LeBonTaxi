import 'package:flutter/material.dart';

class AppColors {
  // Palette de couleurs principale
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color secondary = Color(0xFF10B981);
  static const Color accent = Color(0xFFF59E0B);

  // Palette de fond
  static const Color background = Color(0xFFF3F4F6);
  static const Color backgroundLight = Colors.white;
  static const Color backgroundDark = Color(0xFFE5E7EB);

  // Palette de texte
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);

  // Couleurs sémantiques
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Couleurs neutres et bordures
  static const Color border = Color(0xFFD1D5DB);

  // ✅ Couleurs POI
  static const Color poiRestaurant = Color(0xFFEA580C);
  static const Color poiHotel = Color(0xFF7C3AED);
  static const Color poiGasStation = Color(0xFF0D9488);
  static const Color poiHospital = Color(0xFFDC2626);
  static const Color poiLandmark = Color(0xFF4338CA);
  static const Color poiBank = Color(0xFF059669);

  // ✅ Couleurs de statut trip
  static const Color statusSearching = Color(0xFF6366F1);
  static const Color statusAccepted = Color(0xFF3B82F6);
  static const Color statusArrived = Color(0xFFF59E0B);
  static const Color statusOnTrip = Color(0xFF10B981);
  static const Color statusEnded = Color(0xFF6366F1);

  // ✅ Couleurs trafic
  static const Color trafficLight = Color(0xFF10B981);
  static const Color trafficModerate = Color(0xFFF59E0B);
  static const Color trafficHeavy = Color(0xFFEF4444);

  // ✅ Dark mode prep
  static const Color darkBackground = Color(0xFF111827);
  static const Color darkSurface = Color(0xFF1F2937);
  static const Color darkCard = Color(0xFF374151);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);

  // Ombres
  static final BoxShadow cardShadow = BoxShadow(
    color: Colors.black.withOpacity(0.08),
    blurRadius: 20,
    offset: const Offset(0, 5),
  );

  static final BoxShadow elevatedShadow = BoxShadow(
    color: primary.withOpacity(0.2),
    blurRadius: 25,
    spreadRadius: -10,
    offset: const Offset(0, -10),
  );

  // Dégradés
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient loginGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1A1A), Color(0xFF121212), Color(0xFF0A0A0A)],
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  // ✅ Helper pour couleur de statut
  static Color getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return statusAccepted;
      case 'arrived':
        return statusArrived;
      case 'ontrip':
        return statusOnTrip;
      case 'ended':
        return statusEnded;
      default:
        return textSecondary;
    }
  }

  // ✅ Helper pour couleur POI
  static Color getPOIColor(String category) {
    switch (category) {
      case 'restaurant':
        return poiRestaurant;
      case 'hotel':
        return poiHotel;
      case 'gas_station':
        return poiGasStation;
      case 'hospital':
        return poiHospital;
      case 'landmark':
        return poiLandmark;
      case 'bank':
        return poiBank;
      default:
        return primary;
    }
  }

  // ✅ Getters dynamiques pour le mode sombre
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : background;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : Colors.white;
  }

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : Colors.white;
  }

  static Color getTextPrimaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : textPrimary;
  }

  static Color getTextSecondaryColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : textSecondary;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade800
        : border;
  }
}