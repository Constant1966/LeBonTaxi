import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drivers_app/global/global_var.dart';
import 'package:drivers_app/services/osrm_routing_service.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/services/app_settings_service.dart';
import 'package:drivers_app/widgets/snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class CommonMethods {
  // ============================================================
  // CONNECTIVITÉ
  // ============================================================

  /// Vérifie la connectivité Internet
  Future<void> checkConnectivity(BuildContext context) async {
    var connectionResult = await Connectivity().checkConnectivity();

    if (connectionResult != ConnectivityResult.mobile &&
        connectionResult != ConnectivityResult.wifi) {
      if (!context.mounted) return;
      displaySnackBar(
        "Votre connexion Internet n'est pas disponible. Vérifiez votre connexion et réessayez.",
        context,
      );
    }
  }

  /// Affiche un SnackBar élégant — délègue au SnackBarHelper
  void displaySnackBar(String messageText, BuildContext context, {bool isError = false}) {
    if (!context.mounted) return;
    if (isError) {
      SnackBarHelper.showError(context, messageText);
    } else {
      SnackBarHelper.showInfo(context, messageText);
    }
  }

  // ============================================================
  // GESTION LOCATION UPDATES (Supabase)
  // ============================================================

  /// Désactive les mises à jour de la position pour la page d'accueil
  Future<void> turnOffLocationUpdatesForHomePage() async {
    positionStreamHomePage?.pause();

    // Mettre le chauffeur hors ligne dans Supabase
    await SupabaseService.toggleAvailability(false);
  }

  /// Active les mises à jour de la position pour la page d'accueil
  Future<void> turnOnLocationUpdatesForHomePage() async {
    positionStreamHomePage?.resume();

    if (driverCurrentPosition != null) {
      // Mettre à jour la position dans Supabase
      await SupabaseService.updateDriverLocation(
        latitude: driverCurrentPosition!.latitude,
        longitude: driverCurrentPosition!.longitude,
      );

      // Mettre le chauffeur en ligne dans Supabase
      await SupabaseService.toggleAvailability(true);
    }
  }

  // ============================================================
  // API REQUESTS
  // ============================================================

  /// Envoie une requête à une API (utilisé pour Nominatim, OSRM, etc.)
  static Future<dynamic> sendRequestToAPI(String apiUrl) async {
    try {
      http.Response responseFromAPI = await http.get(Uri.parse(apiUrl));

      if (responseFromAPI.statusCode == 200) {
        String dataFromApi = responseFromAPI.body;
        var dataDecoded = jsonDecode(dataFromApi);
        return dataDecoded;
      } else {
        print("❌ Erreur API: ${responseFromAPI.statusCode}");
        return "error";
      }
    } catch (errorMsg) {
      print("❌ Exception API: $errorMsg");
      return "error";
    }
  }

  // ============================================================
  // ROUTING (OSRM)
  // ============================================================

  /// Récupère les détails de l'itinéraire depuis OSRM
  static Future<DirectionDetails?> getDirectionDetailsFromAPI(
      LatLng source,
      LatLng destination,
      ) async {
    try {
      print(
          "🛣️ Calcul route OSRM: ${source.latitude},${source.longitude} → ${destination.latitude},${destination.longitude}");

      final route = await OSRMRoutingService.getRoute(source, destination);

      if (route == null) {
        print("❌ Pas de route trouvée");
        return null;
      }

      DirectionDetails detailsModel = DirectionDetails();
      detailsModel.distanceTextString = route.distanceText;
      detailsModel.distanceValueDigits = route.distance.round();
      detailsModel.durationTextString = route.durationText;
      detailsModel.durationValueDigits = route.duration;
      detailsModel.encodedPoints = route.geometry; // Déjà décodé pour OSM

      print("✅ Route: ${route.distanceText}, ${route.durationText}");

      return detailsModel;
    } catch (e) {
      print("❌ Exception getDirectionDetailsFromAPI: $e");
      return null;
    }
  }

  // ============================================================
  // CALCUL TARIF
  // ============================================================

  /// Calcule le montant de la course en HTG
  /// Utilise les prix dynamiques définis par le web panel
  String calculateFareAmount(DirectionDetails directionDetails) {
    // Tarification dynamique depuis app_settings
    double distancePerKmAmount = AppSettingsService.pricePerKm;
    double durationPerMinuteAmount = AppSettingsService.pricePerMinute;
    double baseFareAmount = AppSettingsService.baseFare;
    double minFare = AppSettingsService.minFare;

    // Calcul du tarif basé sur la distance
    double totalDistanceTravelFareAmount =
        (directionDetails.distanceValueDigits! / 1000) * distancePerKmAmount;

    // Calcul du tarif basé sur la durée (si applicable)
    double totalDurationSpendFareAmount =
        (directionDetails.durationValueDigits! / 60) *
            durationPerMinuteAmount;

    // Tarif total
    double overAllTotalFareAmount = baseFareAmount +
        totalDistanceTravelFareAmount +
        totalDurationSpendFareAmount;

    // Appliquer le tarif minimum
    if (overAllTotalFareAmount < minFare) {
      overAllTotalFareAmount = minFare;
    }

    // Retourne le montant arrondi à l'entier le plus proche
    return overAllTotalFareAmount.round().toString();
  }

  /// Calcule le montant avec détails (utilise prix dynamiques)
  Map<String, dynamic> calculateFareDetails(DirectionDetails directionDetails) {
    double distancePerKmAmount = AppSettingsService.pricePerKm;
    double baseFare = AppSettingsService.baseFare;
    double pricePerMinute = AppSettingsService.pricePerMinute;
    double minFare = AppSettingsService.minFare;

    double distanceInKm = directionDetails.distanceValueDigits! / 1000;
    double durationMinutes = directionDetails.durationValueDigits! / 60;

    double distanceCost = distanceInKm * distancePerKmAmount;
    double timeCost = durationMinutes * pricePerMinute;
    double totalFare = baseFare + distanceCost + timeCost;

    if (totalFare < minFare) totalFare = minFare;

    return {
      'distanceKm': distanceInKm,
      'distanceText': directionDetails.distanceTextString,
      'durationMinutes': durationMinutes.round(),
      'durationText': directionDetails.durationTextString,
      'fareAmount': totalFare.round(),
      'fareText': '${totalFare.round()} HTG',
      'pricePerKm': distancePerKmAmount,
      'baseFare': baseFare,
      'pricePerMinute': pricePerMinute,
    };
  }

  // ============================================================
  // FORMATAGE
  // ============================================================

  /// Formate une distance en texte
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return "${distanceInMeters.round()} m";
    }
    return "${(distanceInMeters / 1000).toStringAsFixed(1)} km";
  }

  /// Formate une durée en texte
  static String formatDuration(int durationInSeconds) {
    if (durationInSeconds < 60) {
      return "$durationInSeconds sec";
    }
    final minutes = (durationInSeconds / 60).round();
    if (minutes < 60) {
      return "$minutes min";
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return "${hours}h ${remainingMinutes}min";
  }

  /// Formate un montant en HTG
  static String formatCurrency(double amount) {
    return "${amount.round()} HTG";
  }
}

// ============================================================
// MODÈLE DIRECTION DETAILS (Adapté pour OSM)
// ============================================================

class DirectionDetails {
  String? distanceTextString;
  int? distanceValueDigits;
  String? durationTextString;
  int? durationValueDigits;
  List<LatLng>? encodedPoints; // Pour OSM : liste de LatLng

  DirectionDetails({
    this.distanceTextString,
    this.distanceValueDigits,
    this.durationTextString,
    this.durationValueDigits,
    this.encodedPoints,
  });

  /// Distance en kilomètres
  double get distanceInKm =>
      distanceValueDigits != null ? distanceValueDigits! / 1000 : 0.0;

  /// Durée en minutes
  int get durationInMinutes =>
      durationValueDigits != null ? (durationValueDigits! / 60).round() : 0;

  /// Vérifier si les données sont valides
  bool get isValid =>
      distanceValueDigits != null &&
          durationValueDigits != null &&
          encodedPoints != null &&
          encodedPoints!.isNotEmpty;
}