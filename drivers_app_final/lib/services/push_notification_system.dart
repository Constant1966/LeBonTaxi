import 'package:drivers_app/global/global_var.dart';
import 'package:drivers_app/models/trip_details.dart';
import 'package:drivers_app/services/supabase_service.dart';
import 'package:drivers_app/widgets/loading_dialog.dart';
import 'package:drivers_app/widgets/notification_dialog.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// ✅ Service de notifications push FCM + token management
class PushNotificationSystem {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print("⚠️ Permission de notification refusée");
      return;
    }

    print("✅ Permission de notification accordée");
    await generateDeviceRegistrationToken();

    // ✅ Écouter le renouvellement du token FCM
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      print("🔄 Token FCM renouvelé: $newToken");
      fcmToken = newToken;
      await SupabaseService.saveFCMToken(newToken);
    });

    print("✅ PushNotificationSystem initialisé");
  }

  Future<String?> generateDeviceRegistrationToken() async {
    try {
      String? deviceRecognitionToken = await _firebaseMessaging.getToken();

      if (deviceRecognitionToken != null) {
        await SupabaseService.saveFCMToken(deviceRecognitionToken);
        print("✅ Token FCM sauvegardé: $deviceRecognitionToken");

        await _firebaseMessaging.subscribeToTopic("drivers");
        await _firebaseMessaging.subscribeToTopic("users");

        final userId = SupabaseService.getCurrentUser()?.id;
        if (userId != null) {
          await _firebaseMessaging.subscribeToTopic("driver_$userId");
        }

        fcmToken = deviceRecognitionToken;
        return deviceRecognitionToken;
      }
    } catch (e) {
      print("❌ Erreur génération token: $e");
    }
    return null;
  }

  /// Démarrer l'écoute des notifications FCM (foreground, background tap, app killed)
  void startListeningForNewNotification(BuildContext context) {
    // App tuée → ouverte via notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? messageRemote) {
      if (messageRemote != null && messageRemote.data.containsKey("tripID")) {
        String tripID = messageRemote.data["tripID"];
        retrieveTripRequestInfo(tripID, context);
      }
    });

    // App au premier plan → notification reçue
    FirebaseMessaging.onMessage.listen((RemoteMessage? messageRemote) {
      if (messageRemote != null && messageRemote.data.containsKey("tripID")) {
        String tripID = messageRemote.data["tripID"];
        retrieveTripRequestInfo(tripID, context);
      }
    });

    // App en arrière-plan → utilisateur tape sur la notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? messageRemote) {
      if (messageRemote != null && messageRemote.data.containsKey("tripID")) {
        String tripID = messageRemote.data["tripID"];
        retrieveTripRequestInfo(tripID, context);
      }
    });

    print("✅ Écoute FCM activée (3 canaux)");
  }

  void retrieveTripRequestInfo(String tripID, BuildContext context) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const LoadingDialog(
        messageText: "Chargement de la course...",
      ),
    );

    SupabaseService.getTripDetails(tripID).then((tripData) {
      if (context.mounted) Navigator.pop(context);

      if (tripData != null) {
        print("✅ Données course récupérées");

        TripDetails tripDetailsInfo = TripDetails.fromSupabase(tripData);
        tripDetailsInfo.tripID = tripID;

        if (context.mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) => NotificationDialog(
              tripDetailsInfo: tripDetailsInfo,
            ),
          );
        }
      } else {
        print("❌ Course introuvable: $tripID");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Course introuvable"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }).catchError((error) {
      if (context.mounted) Navigator.pop(context);
      print("❌ Erreur récupération course: $error");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: $error"),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }
}