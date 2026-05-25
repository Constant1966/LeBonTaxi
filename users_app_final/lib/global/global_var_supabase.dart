import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// ✅ VARIABLES GLOBALES PRINCIPALES (Supabase)
String userName = "";
String userPhone = "";
String userEmail = "";
String? userID;

// ✅ Position actuelle
Position? currentPosition;
String? pickUpAddress;
String? dropOffAddress;

// ✅ Infos Abonnement (Supabase)
String? userSubscriptionPlanId;
DateTime? userSubscriptionEndDate;
double currentUserDiscount = 0.0;
bool get isUserSubscribed => 
    userSubscriptionEndDate != null && 
    userSubscriptionEndDate!.isAfter(DateTime.now());

// ✅ Tarification globale (Supabase app_settings)
double globalBaseFare = 50.0;
double globalPerKmRate = 150.0;
double globalMinimumFare = 100.0;

// ✅ Position initiale pour OSM (Port-au-Prince, Haïti)
const LatLng haitiInitialPosition = LatLng(18.5944, -72.3074);
const double initialZoom = 14.0;

// ✅ Méthode pour mettre à jour les infos utilisateur (Supabase)
void updateUserInfo({
  required String name,
  required String phone,
  required String email,
  required String uid,
}) {
  userName = name;
  userPhone = phone;
  userEmail = email;
  userID = uid;
}

// ✅ Méthode pour effacer les données utilisateur
void clearUserData() {
  userName = "";
  userPhone = "";
  userEmail = "";
  userID = null;
  currentPosition = null;
  pickUpAddress = null;
  dropOffAddress = null;
  userSubscriptionPlanId = null;
  userSubscriptionEndDate = null;
  currentUserDiscount = 0.0;

  print("🧹 Données utilisateur effacées");
}

// ✅ Extensions LatLng pour Supabase
extension LatLngExtensions on LatLng {
  /// Convertit en texte pour stockage
  String toStorageString() {
    return "$latitude,$longitude";
  }

  /// Convertit en Map pour Supabase
  Map<String, dynamic> toSupabaseMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Crée un LatLng depuis un Map Supabase
  static LatLng fromSupabaseMap(Map<dynamic, dynamic> map) {
    return LatLng(
      double.parse(map['latitude'].toString()),
      double.parse(map['longitude'].toString()),
    );
  }

  /// Crée un LatLng depuis des nombres
  static LatLng fromNumbers(dynamic lat, dynamic lng) {
    return LatLng(
      double.parse(lat.toString()),
      double.parse(lng.toString()),
    );
  }
}

// ✅ Helper pour Position → LatLng
extension PositionExtensions on Position {
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }

  Map<String, dynamic> toSupabaseMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}