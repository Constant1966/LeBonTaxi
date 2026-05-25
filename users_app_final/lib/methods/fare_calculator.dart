import '../global/global_var_supabase.dart';

/// Utilitaire centralisé pour le calcul des tarifs
/// Évite la duplication de la logique de calcul à travers l'app
class FareCalculator {
  /// Calcule le tarif final en tenant compte de la réduction abonnement
  ///
  /// [distanceKm] - Distance de la course en kilomètres
  /// [baseFare] - Tarif de base (défaut: globalBaseFare depuis Supabase)
  /// [perKmRate] - Tarif par km (défaut: globalPerKmRate depuis Supabase)
  /// [minimumFare] - Tarif minimum (défaut: globalMinimumFare depuis Supabase)
  /// [discountPercentage] - Pourcentage de réduction abonnement (0-100)
  /// [trafficMultiplier] - Multiplicateur de trafic (1.0 = normal)
  static int calculate({
    required double distanceKm,
    double? baseFare,
    double? perKmRate,
    double? minimumFare,
    double discountPercentage = 0.0,
    double trafficMultiplier = 1.0,
  }) {
    final base = baseFare ?? globalBaseFare;
    final rate = perKmRate ?? globalPerKmRate;
    final min = minimumFare ?? globalMinimumFare;

    // Calcul de base
    double subtotal = base + (distanceKm * rate);

    // Appliquer le multiplicateur de trafic
    if (trafficMultiplier > 1.0) {
      subtotal *= trafficMultiplier;
    }

    // Appliquer la réduction abonnement
    if (discountPercentage > 0) {
      subtotal -= subtotal * (discountPercentage / 100.0);
    }

    int fare = subtotal.ceil();
    if (fare < min) fare = min.toInt();
    return fare;
  }

  /// Formate le tarif avec la devise
  static String format(int fare, {String currency = 'HTG'}) {
    return '$fare $currency';
  }

  /// Calcule et formate en une seule étape
  static String calculateFormatted({
    required double distanceKm,
    double discountPercentage = 0.0,
    double trafficMultiplier = 1.0,
    String currency = 'HTG',
  }) {
    final fare = calculate(
      distanceKm: distanceKm,
      discountPercentage: discountPercentage,
      trafficMultiplier: trafficMultiplier,
    );
    return format(fare, currency: currency);
  }
}
