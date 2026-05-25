import 'package:drivers_app/services/app_settings_service.dart';

/// Calculateur de tarifs centralisé
/// Utilise les paramètres dynamiques du web panel (via AppSettingsService)
class FareCalculator {
  /// Calcule le tarif d'une course
  /// [distanceMeters] : distance en mètres
  /// [durationSeconds] : durée en secondes
  /// [userDiscountPercent] : réduction de l'utilisateur abonné (0-100)
  static double calculateFare({
    required int distanceMeters,
    required int durationSeconds,
    double userDiscountPercent = 0.0,
  }) {
    final breakdown = getFareBreakdown(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      userDiscountPercent: userDiscountPercent,
    );
    return breakdown['totalFare'] as double;
  }

  /// Calcule le tarif et retourne un détail complet
  static Map<String, dynamic> getFareBreakdown({
    required int distanceMeters,
    required int durationSeconds,
    double userDiscountPercent = 0.0,
  }) {
    // Récupérer les paramètres dynamiques
    final pricePerKm = AppSettingsService.pricePerKm;
    final baseFare = AppSettingsService.baseFare;
    final pricePerMinute = AppSettingsService.pricePerMinute;
    final minFare = AppSettingsService.minFare;

    // Calculs
    final distanceKm = distanceMeters / 1000.0;
    final durationMinutes = durationSeconds / 60.0;

    final distanceCost = distanceKm * pricePerKm;
    final timeCost = durationMinutes * pricePerMinute;
    final subtotal = baseFare + distanceCost + timeCost;

    // Appliquer la réduction
    double discount = 0.0;
    if (userDiscountPercent > 0) {
      discount = subtotal * (userDiscountPercent / 100.0);
    }

    double totalFare = subtotal - discount;

    // Appliquer le tarif minimum
    if (totalFare < minFare) {
      totalFare = minFare;
      // Recalculer la réduction effective si on est au minimum
      if (subtotal > minFare && userDiscountPercent > 0) {
        discount = subtotal - minFare;
      } else {
        discount = 0.0;
      }
    }

    return {
      'distanceKm': distanceKm,
      'durationMinutes': durationMinutes.round(),
      'pricePerKm': pricePerKm,
      'baseFare': baseFare,
      'pricePerMinute': pricePerMinute,
      'distanceCost': distanceCost,
      'timeCost': timeCost,
      'subtotal': subtotal,
      'discountPercent': userDiscountPercent,
      'discountAmount': discount,
      'totalFare': totalFare.roundToDouble(),
      'totalFareRounded': totalFare.round(),
      'minFare': minFare,
      'isMinFareApplied': totalFare <= minFare && subtotal > 0,
    };
  }

  /// Calcule le tarif simple (string) — compatible avec l'ancien format
  static String calculateFareAmount({
    required int distanceMeters,
    required int durationSeconds,
    double userDiscountPercent = 0.0,
  }) {
    final fare = calculateFare(
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
      userDiscountPercent: userDiscountPercent,
    );
    return fare.round().toString();
  }

  /// Formater un montant en HTG
  static String formatCurrency(double amount) {
    return '${amount.round()} HTG';
  }
}
