import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:users_app/appInfo/app_info.dart';
import 'package:users_app/global/global_var_supabase.dart';
import 'package:users_app/models/address_model.dart';
import 'package:users_app/widgets/snackbar_helper.dart';

class CommonMethods {

  /// Vérifie la connectivité (compatible connectivity_plus v5+)
  Future<bool> checkConnectivity(BuildContext context) async {
    final connectionResult = await Connectivity().checkConnectivity();

    // connectivity_plus v5+ retourne List<ConnectivityResult>
    final bool hasConnection;
    if (connectionResult is List) {
      hasConnection = (connectionResult as List).any(
        (r) => r == ConnectivityResult.mobile || r == ConnectivityResult.wifi,
      );
    } else {
      hasConnection = connectionResult == ConnectivityResult.mobile ||
          connectionResult == ConnectivityResult.wifi;
    }

    if (!hasConnection) {
      if (context.mounted) {
        displaySnackBar(
          "Votre connexion Internet n'est pas disponible.",
          context,
          isError: true,
        );
      }
      return false;
    }
    return true;
  }

  /// Affiche un SnackBar élégant — délègue au SnackBarHelper
  void displaySnackBar(
      String messageText,
      BuildContext context, {
        bool isError = false,
        Duration duration = const Duration(seconds: 3),
      }) {
    if (!context.mounted) return;

    if (isError) {
      SnackBarHelper.showError(context, messageText);
    } else {
      SnackBarHelper.showSuccess(context, messageText);
    }
  }

  /// Envoie une requête HTTP GET
  static Future<dynamic> sendRequestToAPI(String apiUrl) async {
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print("Erreur API: $e");
      return null;
    }
  }

  /// ✅ Reverse Geocoding via Nominatim OSM (plus de Google Maps)
  static Future<String> convertToAddress(
      Position position,
      BuildContext context,
      ) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
            '?lat=${position.latitude}'
            '&lon=${position.longitude}'
            '&format=json',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'LeBonTaxi/1.0 (contact@lebontaxi.com)',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final address = data['display_name'] as String? ?? 'Adresse inconnue';

        if (context.mounted) {
          final model = AddressModel(
            humanReadableAddress: address,
            placeName: address,
            latitudePosition: position.latitude,
            longitudePosition: position.longitude,
          );
          Provider.of<AppInfo>(context, listen: false).updatePickUpLocation(model);

          // Mettre à jour la variable globale
          pickUpAddress = address;
        }

        return address;
      }
    } catch (e) {
      print("❌ Erreur reverse geocoding: $e");
    }

    return "Adresse non disponible";
  }
}