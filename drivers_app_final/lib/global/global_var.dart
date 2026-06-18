import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Position initiale de la caméra (Port-au-Prince, Haïti)
const LatLng haitiInitialPosition = LatLng(18.5944, -72.3074);
const double initialZoom = 13.0;

// ============================================================
// STREAMS & SUBSCRIPTIONS
// ============================================================

// Abonnements aux flux de position
StreamSubscription<Position>? positionStream;
StreamSubscription<Position>? positionStreamHomePage;

// Timeout pour les demandes de course (variable globale)
int tripRequestTimeout = 20;

// ============================================================
// POSITION ACTUELLE
// ============================================================

Position? currentPosition;
Position? driverCurrentPosition;

// ============================================================
// INFORMATIONS CHAUFFEUR
// ============================================================

String driverId = "";
String driverName = "";
String driverPhone = "";
String driverPhoto = "";
String driverEmail = "";
String driverDocumentStatus = 'pending';
String? documentsRejectionNote;
List<Map<String, dynamic>> driverDocuments = [];
dynamic documentRealtimeChannel;


// ============================================================
// INFORMATIONS VÉHICULE
// ============================================================

String carModel = "";
String carColor = "";
String carNumber = "";
String carYear = "";
String carFrontPhoto = "";
String carBackPhoto = "";
String carSidePhoto = "";

// ============================================================
// STATUT EN LIGNE
// ============================================================

bool isDriverCurrentlyOnline = false;

// ============================================================
// ABONNEMENT CHAUFFEUR
// ============================================================

bool isDriverSubscribed = false;
String? currentSubscriptionPlanName;
double driverDiscountPercent = 0.0;
DateTime? subscriptionExpiresAt;

// ============================================================
// FCM TOKEN
// ============================================================

String fcmToken = "";

// ============================================================
// MÉTHODE POUR EFFACER TOUTES LES DONNÉES
// ============================================================

void clearDriverData() {
  driverId = "";
  driverName = "";
  driverPhone = "";
  driverPhoto = "";
  driverEmail = "";
  carModel = "";
  carColor = "";
  carNumber = "";
  carYear = "";
  carFrontPhoto = "";
  carBackPhoto = "";
  carSidePhoto = "";
  fcmToken = "";
  isDriverCurrentlyOnline = false;
  currentPosition = null;
  driverCurrentPosition = null;
  tripRequestTimeout = 20;

  // Reset abonnement
  isDriverSubscribed = false;
  currentSubscriptionPlanName = null;
  driverDiscountPercent = 0.0;
  subscriptionExpiresAt = null;

  // Reset documents
  driverDocumentStatus = 'pending';
  documentsRejectionNote = null;
  driverDocuments = [];
  documentRealtimeChannel?.unsubscribe();
  documentRealtimeChannel = null;
}

// ============================================================
// MÉTHODES DE NETTOYAGE DES STREAMS
// ============================================================

void disposePositionStream() {
  positionStream?.cancel();
  positionStream = null;
}

void disposePositionStreamHomePage() {
  positionStreamHomePage?.cancel();
  positionStreamHomePage = null;
}

void disposeAllStreams() {
  disposePositionStream();
  disposePositionStreamHomePage();
}

// ============================================================
// HELPERS POUR LA CONVERSION LatLng
// ============================================================

extension LatLngExtensions on LatLng {
  /// Convertit un LatLng en texte pour stockage
  String toStorageString() {
    return "$latitude,$longitude";
  }

  /// Crée un LatLng depuis un texte
  static LatLng fromStorageString(String text) {
    final parts = text.split(',');
    return LatLng(
      double.parse(parts[0]),
      double.parse(parts[1]),
    );
  }

  /// Convertit en Map pour JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Crée un LatLng depuis un Map JSON
  static LatLng fromJson(Map<dynamic, dynamic> map) {
    return LatLng(
      double.parse(map['latitude'].toString()),
      double.parse(map['longitude'].toString()),
    );
  }
}

// ============================================================
// HELPER POUR Position → LatLng
// ============================================================

extension PositionExtensions on Position {
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

// ============================================================
// CALCUL DE DISTANCE
// ============================================================

double calculateDistance(LatLng start, LatLng end) {
  return Geolocator.distanceBetween(
    start.latitude,
    start.longitude,
    end.latitude,
    end.longitude,
  ) / 1000; // Retourne en km
}


/// Retourne true si tous les documents obligatoires ont ete soumis.
bool get hasSubmittedAllRequiredDocs {
  const required = [
    'drivers_license',
    'criminal_record',
    'identity_card',
    'vehicle_registration',
    'vehicle_insurance',
  ];
  final submittedTypes =
      driverDocuments.map((d) => d['document_type'] as String).toSet();
  return required.every(submittedTypes.contains);
}

/// Retourne les documents rejetes.
List<Map<String, dynamic>> get rejectedDocuments =>
    driverDocuments.where((d) => d['status'] == 'rejected').toList();

/// Retourne les documents en attente.
List<Map<String, dynamic>> get pendingDocuments =>
    driverDocuments.where((d) => d['status'] == 'pending').toList();