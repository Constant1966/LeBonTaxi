import 'package:latlong2/latlong.dart';

/// Configuration pour les cartes OpenStreetMap
class MapConfig {
  // ============================================================
  // POSITION PAR DÉFAUT (Port-au-Prince, Haïti)
  // ============================================================

  static const LatLng haitiCenter = LatLng(18.5944, -72.3074);
  static const double defaultZoom = 13.0;
  static const double minZoom = 5.0;
  static const double maxZoom = 19.0;

  // ============================================================
  // URL DES TUILES OPENSTREETMAP
  // ============================================================

  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // ============================================================
  // USER-AGENT (Obligatoire pour Nominatim)
  // ============================================================

  static const String userAgent = 'LeBonTaxi/1.0 (contact@lebontaxi.ht)';

  // ============================================================
  // URL NOMINATIM (Geocoding)
  // ============================================================

  static const String nominatimUrl = 'https://nominatim.openstreetmap.org';

  // ============================================================
  // URL OSRM (Routing)
  // ============================================================

  static const String osrmUrl = 'https://router.project-osrm.org';

  // ============================================================
  // ATTRIBUTION OSM (Obligatoire légalement)
  // ============================================================

  static const String osmAttribution = '© OpenStreetMap contributors';
  static const String osmAttributionUrl = 'https://openstreetmap.org/copyright';

  // ============================================================
  // PARAMÈTRES DE LA CARTE
  // ============================================================

  /// Padding par défaut pour fitBounds
  static const double defaultPadding = 50.0;

  /// Durée d'animation par défaut
  static const Duration animationDuration = Duration(milliseconds: 500);

  /// Distance minimale de mouvement pour mettre à jour la position (en mètres)
  static const double minDistanceFilter = 10.0;

  // ============================================================
  // COULEURS DES MARKERS & ROUTES
  // ============================================================

  /// Couleur du marker de pickup (vert)
  static const int pickupMarkerColor = 0xFF10B981;

  /// Couleur du marker de dropoff (rouge)
  static const int dropoffMarkerColor = 0xFFEF4444;

  /// Couleur du marker du chauffeur (bleu)
  static const int driverMarkerColor = 0xFF3B82F6;

  /// Couleur de la route (bleu)
  static const int routeColor = 0xFF3B82F6;

  // ============================================================
  // LIMITES GÉOGRAPHIQUES (Haïti)
  // ============================================================

  /// Limite nord d'Haïti
  static const double haitiNorthBound = 20.0;

  /// Limite sud d'Haïti
  static const double haitiSouthBound = 18.0;

  /// Limite est d'Haïti
  static const double haitiEastBound = -71.5;

  /// Limite ouest d'Haïti
  static const double haitiWestBound = -74.5;

  /// Vérifier si une position est en Haïti
  static bool isInHaiti(LatLng position) {
    return position.latitude >= haitiSouthBound &&
        position.latitude <= haitiNorthBound &&
        position.longitude >= haitiWestBound &&
        position.longitude <= haitiEastBound;
  }

  // ============================================================
  // ZONES IMPORTANTES (Port-au-Prince)
  // ============================================================

  static const LatLng aeroport = LatLng(18.5799, -72.2925);
  static const LatLng petionville = LatLng(18.5125, -72.2852);
  static const LatLng delmas = LatLng(18.5463, -72.3025);
  static const LatLng carrefour = LatLng(18.5418, -72.3990);
}